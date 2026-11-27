#!/usr/bin/env python3
"""
Incremental Ookla Bronze -> Silver -> Gold EMR Step.

Processes a single newly uploaded Ookla mobile Parquet file from Bronze
(e.g. s3://<bronze>/incoming/ookla/2026-04-01_performance_mobile_tiles.parquet),
performs territorial filtering, quality validation, spatial join against the
1,890 INEI districts, writes Silver tiles + quarantines, publishes an atomic
idempotent Parquet file into Gold panel_distrital/year=<year>/incremental_<year>Q<q>.parquet,
and optionally triggers a QuickSight SPICE refresh.
"""

import argparse
import hashlib
import json
import math
import re
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from tempfile import TemporaryDirectory

import boto3
import geopandas as gpd
import numpy as np
import pyarrow as pa
import pyarrow.parquet as pq
import shapely
from pyspark import StorageLevel
from pyspark.sql import SparkSession, Window, functions as F
from pyspark.sql.types import StructType

FILENAME_PATTERN = re.compile(r"^(\d{4})-(01|04|07|10)-01_performance_mobile_tiles\.parquet$")


def parse_s3_uri(uri: str):
    if not uri.startswith("s3://"):
        raise ValueError(f"Expected s3:// URI, got: {uri}")
    bucket, _, key = uri[5:].partition("/")
    return bucket, key


def read_s3_json(s3, uri: str):
    bucket, key = parse_s3_uri(uri)
    body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    return json.loads(body.decode("utf-8"))


def save_s3_json(s3, uri: str, payload: dict):
    bucket, key = parse_s3_uri(uri)
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(payload, indent=2, ensure_ascii=False).encode("utf-8"),
        ContentType="application/json",
    )


def download_verified_object(s3, item: dict, folder: Path) -> Path:
    bucket, key = item["bucket"], item["key"]
    path = folder / PurePosixPath(key).name
    extra = {"VersionId": item["version_id"]} if item.get("version_id") else None
    s3.download_file(bucket, key, str(path), ExtraArgs=extra)
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024**2), b""):
            digest.update(chunk)
    if digest.hexdigest() != item["sha256"] or path.stat().st_size != item["bytes"]:
        raise ValueError(f"SHA-256 mismatch for s3://{bucket}/{key}")
    return path


def load_districts(path: Path) -> gpd.GeoDataFrame:
    if path.suffix.lower() in {".rar", ".zip"}:
        names = subprocess.check_output(["bsdtar", "-tf", str(path)], text=True).splitlines()
        geopackages = [name for name in names if name.lower().endswith(".gpkg")]
        if len(geopackages) != 1:
            raise ValueError("INEI archive must contain exactly one GeoPackage.")
        output = path.with_suffix(".gpkg")
        with output.open("wb") as stream:
            subprocess.run(["bsdtar", "-xOf", str(path), geopackages[0]], stdout=stream, check=True)
        path = output
    data = gpd.read_file(path)
    data.columns = data.columns.str.strip().str.lower()
    data = data[["ubigeo", "nombdep", "nombprov", "nombdist", "geometry"]].to_crs(4326)
    data["ubigeo"] = data.ubigeo.astype("string").str.strip().str.zfill(6)
    repair = ~data.geometry.is_valid
    data.loc[repair, "geometry"] = data.loc[repair].geometry.buffer(0)
    data["superficie_km2"] = data.to_crs(6933).area / 1_000_000
    return data.sort_values("ubigeo").reset_index(drop=True)


def assign_districts(frame, geo_broadcast):
    schema = StructType(list(frame.schema.fields)).add("ubigeo", "string").add("coincidencias", "integer")

    def locate(batches):
        codes, polygons = geo_broadcast.value
        tree = shapely.STRtree(shapely.from_wkb(polygons))
        for batch in batches:
            points = shapely.points(batch.tile_x.to_numpy(), batch.tile_y.to_numpy())
            point_index, polygon_index = tree.query(points, predicate="covered_by")
            matches = np.bincount(point_index, minlength=len(batch)).astype("int32")
            unique = matches[point_index] == 1
            district = np.full(len(batch), None, dtype=object)
            district[point_index[unique]] = codes[polygon_index[unique]]
            yield batch.assign(ubigeo=district, coincidencias=matches)

    return frame.mapInPandas(locate, schema)


def read_single_ookla_quarter(spark, input_uri: str, period_id: int, bounds):
    raw = spark.read.parquet(input_uri)
    tiles = raw.select(
        "quadkey",
        F.col("avg_d_kbps").cast("long").alias("avg_d_kbps"),
        F.col("tests").cast("long").alias("tests"),
        F.col("devices").cast("long").alias("devices"),
        F.lit(period_id).cast("int").alias("period_id"),
    )
    west, south, east, north = map(float, bounds)
    x0, x1 = [int((lon + 180) * 64 / 360) for lon in (west, east)]
    y0, y1 = [int((1 - math.asinh(math.tan(math.radians(lat))) / math.pi) * 32) for lat in (north, south)]
    prefixes = [
        "".join(str(((x >> bit) & 1) + 2 * ((y >> bit) & 1)) for bit in range(5, -1, -1))
        for x in range(x0, x1 + 1)
        for y in range(y0, y1 + 1)
    ]
    candidates = tiles.filter(
        F.substring("quadkey", 1, 6).isin(prefixes) & F.col("quadkey").rlike(r"^[0-3]{16}$")
    )
    x = F.expr("aggregate(sequence(1, 16), 0, (a, i) -> a * 2 + (int(substring(quadkey, i, 1)) & 1))")
    y = F.expr("aggregate(sequence(1, 16), 0, (a, i) -> a * 2 + int(int(substring(quadkey, i, 1)) DIV 2))")
    lat = F.degrees(F.atan(F.sinh(math.pi * (1 - 2 * (y + 0.5) / 65536))))
    return (
        candidates.withColumn("tile_x", (x + 0.5) / 65536 * 360 - 180)
        .withColumn("tile_y", lat)
        .filter(F.col("tile_x").between(west, east) & F.col("tile_y").between(south, north))
    )


def trigger_quicksight_refresh(region: str, dataset_id: str) -> dict:
    sts = boto3.client("sts", region_name=region)
    account_id = sts.get_caller_identity()["Account"]
    qs = boto3.client("quicksight", region_name=region)
    ingestion_id = f"inc-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{uuid.uuid4().hex[:8]}"
    resp = qs.create_ingestion(
        AwsAccountId=account_id,
        DataSetId=dataset_id,
        IngestionId=ingestion_id,
        IngestionType="FULL_REFRESH",
    )
    return {"ingestion_id": ingestion_id, "status": resp.get("IngestionStatus")}


def main():
    parser = argparse.ArgumentParser(description="Incremental Ookla Bronze -> Silver -> Gold processor")
    parser.add_argument("--input-uri", required=True)
    parser.add_argument("--bronze-manifest-uri", required=True)
    parser.add_argument("--silver-manifest-uri", required=True)
    parser.add_argument("--silver-bucket", required=True)
    parser.add_argument("--gold-bucket", required=True)
    parser.add_argument("--gold-run-id", required=True)
    parser.add_argument("--operations-bucket", required=True)
    parser.add_argument("--region", default="us-east-1")
    parser.add_argument("--quicksight-dataset-id", default="")
    args = parser.parse_args()

    filename = PurePosixPath(parse_s3_uri(args.input_uri)[1]).name
    match = FILENAME_PATTERN.match(filename)
    if not match:
        raise ValueError(f"Unsupported Ookla filename format: {filename}")
    year = int(match.group(1))
    month = int(match.group(2))
    quarter = (month - 1) // 3 + 1
    period_id = year * 4 + (quarter - 1)
    quarter_tag = f"{year}Q{quarter}"

    print(f"[INFO] Starting incremental processing for {quarter_tag} (period_id={period_id}) from {args.input_uri}")

    s3 = boto3.client("s3", region_name=args.region)
    bronze_manifest = read_s3_json(s3, args.bronze_manifest_uri)
    silver_manifest = read_s3_json(s3, args.silver_manifest_uri)

    district_items = [
        item for item in bronze_manifest["objects"]
        if item["source"] == "inei" and PurePosixPath(item["key"]).name.lower() == "distrito.rar"
    ]
    if len(district_items) != 1:
        raise ValueError("Could not uniquely locate Distrito.rar in bronze manifest.")

    spark = (
        SparkSession.builder.master("yarn")
        .appName(f"american-tower-incremental-{quarter_tag}")
        .config("spark.sql.parquet.compression.codec", "snappy")
        .config("spark.sql.adaptive.enabled", "true")
        .getOrCreate()
    )

    try:
        with TemporaryDirectory(prefix="inc-ookla-") as tmpdir:
            district_path = download_verified_object(s3, district_items[0], Path(tmpdir))
            geography = load_districts(district_path)

            geo_bc = spark.sparkContext.broadcast(
                (geography.ubigeo.to_numpy(), geography.geometry.to_wkb().tolist())
            )
            try:
                raw = read_single_ookla_quarter(spark, args.input_uri, period_id, geography.total_bounds)
                keys = ["period_id", "quadkey"]
                inspected = raw.withColumn(
                    "motivo",
                    F.when(F.col("period_id").isNull(), "periodo_invalido")
                    .when(
                        F.col("tests").isNull()
                        | (F.col("tests") <= 0)
                        | F.col("devices").isNull()
                        | (F.col("devices") <= 0)
                        | (F.col("devices") > F.col("tests")),
                        "pruebas_o_dispositivos_invalidos",
                    )
                    .when(F.col("avg_d_kbps").isNull() | (F.col("avg_d_kbps") <= 0), "descarga_invalida")
                    .when(F.count("*").over(Window.partitionBy(*keys)) > 1, "clave_duplicada"),
                ).persist(StorageLevel.DISK_ONLY)

                assigned = assign_districts(inspected.filter("motivo IS NULL").drop("motivo"), geo_bc).withColumn(
                    "motivo",
                    F.when(F.col("coincidencias") == 0, "fuera_de_poligonos").when(
                        F.col("coincidencias") > 1, "asignacion_ambigua"
                    ),
                ).persist(StorageLevel.DISK_ONLY)

                rules = {r.motivo or "validas": r["count"] for r in inspected.groupBy("motivo").count().collect()}
                spatial = {r.motivo or "asignadas": r["count"] for r in assigned.groupBy("motivo").count().collect()}

                ops_prefix = f"s3://{args.operations_bucket}/incremental/ookla/{quarter_tag}"
                inspected.filter("motivo IS NOT NULL").write.mode("overwrite").parquet(
                    f"{ops_prefix}/cuarentena/calidad"
                )
                assigned.filter("motivo IS NOT NULL").write.mode("overwrite").parquet(
                    f"{ops_prefix}/cuarentena/espacial"
                )

                clean_tiles = assigned.filter("motivo IS NULL").drop("motivo", "coincidencias")
                silver_tiles_uri = (
                    f"s3://{args.silver_bucket}/incremental/ookla_teselas/period_id={period_id}"
                )
                clean_tiles.write.mode("overwrite").option("compression", "snappy").parquet(silver_tiles_uri)

                # Aggregate to Gold panel_distrital grain (1,890 rows for this quarter)
                stats = clean_tiles.groupBy("ubigeo", "period_id").agg(
                    (
                        F.sum(F.col("avg_d_kbps").cast("double") * F.col("tests")) / F.sum("tests") / 1000.0
                    ).alias("vel_descarga_mbps"),
                    F.sum("tests").cast("long").alias("tests"),
                    F.count("*").cast("long").alias("teselas_observadas"),
                )

                districts_df = spark.read.parquet(silver_manifest["tables"]["distritos"])
                panel_quarter = (
                    districts_df.withColumn("period_id", F.lit(period_id).cast("int"))
                    .join(stats, ["ubigeo", "period_id"], "left")
                    .withColumn("quarter", F.lit(quarter).cast("int"))
                    .withColumn("observado", F.col("vel_descarga_mbps").isNotNull())
                    .select(
                        "ubigeo",
                        "period_id",
                        "departamento",
                        "provincia",
                        "distrito",
                        "superficie_km2",
                        "vel_descarga_mbps",
                        "tests",
                        "teselas_observadas",
                        "quarter",
                        "observado",
                    )
                )

                pdf = panel_quarter.toPandas()
                if len(pdf) != 1890:
                    raise ValueError(f"Expected 1890 district rows for {quarter_tag}, got {len(pdf)}")

                arrow_schema = pa.schema([
                    ("ubigeo", pa.string()),
                    ("period_id", pa.int32()),
                    ("departamento", pa.string()),
                    ("provincia", pa.string()),
                    ("distrito", pa.string()),
                    ("superficie_km2", pa.float64()),
                    ("vel_descarga_mbps", pa.float64()),
                    ("tests", pa.int64()),
                    ("teselas_observadas", pa.int64()),
                    ("quarter", pa.int32()),
                    ("observado", pa.bool_()),
                ])
                table = pa.Table.from_pandas(pdf, schema=arrow_schema, preserve_index=False)
                local_parquet = Path(tmpdir) / f"incremental_{quarter_tag}.parquet"
                pq.write_table(table, local_parquet, compression="snappy")

                gold_key = f"run_id={args.gold_run_id}/panel_distrital/year={year}/incremental_{quarter_tag}.parquet"
                s3.upload_file(str(local_parquet), args.gold_bucket, gold_key)
                gold_uri = f"s3://{args.gold_bucket}/{gold_key}"
                print(f"[INFO] Published atomic Gold quarter file: {gold_uri}")

                qs_result = None
                if args.quicksight_dataset_id:
                    try:
                        qs_result = trigger_quicksight_refresh(args.region, args.quicksight_dataset_id)
                        print(f"[INFO] Triggered QuickSight SPICE refresh: {qs_result}")
                    except Exception as exc:
                        qs_result = {"error": str(exc)}
                        print(f"[WARN] QuickSight refresh skipped/failed: {exc}")

                receipt = {
                    "quarter": quarter_tag,
                    "year": year,
                    "quarter_num": quarter,
                    "period_id": period_id,
                    "input_uri": args.input_uri,
                    "silver_tiles_uri": silver_tiles_uri,
                    "gold_file_uri": gold_uri,
                    "gold_rows": int(len(pdf)),
                    "observed_districts": int(pdf["observado"].sum()),
                    "quality_rules": rules,
                    "spatial_rules": spatial,
                    "quicksight_refresh": qs_result,
                    "completed_at_utc": datetime.now(timezone.utc).isoformat(),
                }
                save_s3_json(s3, f"{ops_prefix}/_SUCCESS.json", receipt)
                print(f"[INFO] Completed {quarter_tag}: {receipt['observed_districts']}/1890 observed districts.")
            finally:
                geo_bc.destroy()
    finally:
        spark.stop()


if __name__ == "__main__":
    main()
