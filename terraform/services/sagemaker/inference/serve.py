"""
SageMaker Serverless CPU Inference Service for Spark MLlib PipelineModels.

Implements SageMaker's /ping and /invocations HTTP endpoints on port 8080.
Loads each team member's Spark MLlib PipelineModel from:
  s3://<ARTIFACTS_BUCKET>/models/<model_name>/
(downloaded once to local /tmp/models/<model_name> and cached in memory),
runs real PySpark MLlib .transform() in local[1] mode, and optionally persists
predictions to s3://<GOLD_BUCKET>/predicciones_modelos/ for live QuickSight DIRECT_QUERY.
"""

import io
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

import boto3
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from flask import Flask, jsonify, request
from pyspark.ml import PipelineModel
from pyspark.sql import SparkSession

app = Flask(__name__)

REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
ARTIFACTS_BUCKET = os.environ.get("ARTIFACTS_BUCKET", "")
GOLD_BUCKET = os.environ.get("GOLD_BUCKET", "")
PREDICCIONES_PREFIX = os.environ.get("PREDICCIONES_PREFIX", "predicciones_modelos/")
LOCAL_MODEL_ROOT = Path("/tmp/models")

s3 = boto3.client("s3", region_name=REGION)
MODEL_CACHE = {}
_SPARK = None

PREDICTION_SCHEMA = pa.schema([
    ("inference_id", pa.string()),
    ("inference_timestamp", pa.timestamp("us")),
    ("modelo", pa.string()),
    ("autor", pa.string()),
    ("ubigeo", pa.string()),
    ("year_objetivo", pa.int32()),
    ("quarter_objetivo", pa.int32()),
    ("vel_origen_mbps", pa.float64()),
    ("pred_descarga_mbps", pa.float64()),
    ("indice_prioridad", pa.float64()),
])


def get_spark() -> SparkSession:
    global _SPARK
    if _SPARK is None:
        _SPARK = (
            SparkSession.builder.master("local[1]")
            .appName("american-tower-sagemaker-mllib")
            .config("spark.driver.memory", "1536m")
            .config("spark.sql.shuffle.partitions", "2")
            .config("spark.ui.enabled", "false")
            .getOrCreate()
        )
        _SPARK.sparkContext.setLogLevel("ERROR")
    return _SPARK


def download_s3_prefix(bucket: str, prefix: str, target_dir: Path) -> Path:
    paginator = s3.get_paginator("list_objects_v2")
    found = False
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/"):
                continue
            rel = key[len(prefix):].lstrip("/")
            dest = target_dir / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            s3.download_file(bucket, key, str(dest))
            found = True
    if not found:
        raise FileNotFoundError(f"No Spark MLlib model artifacts found at s3://{bucket}/{prefix}")
    return target_dir


def load_spark_model(model_name: str) -> PipelineModel:
    if model_name in MODEL_CACHE:
        return MODEL_CACHE[model_name]
    if not ARTIFACTS_BUCKET:
        raise RuntimeError("ARTIFACTS_BUCKET environment variable is not configured.")
    get_spark()
    local_dir = LOCAL_MODEL_ROOT / model_name
    if not (local_dir / "metadata").exists():
        download_s3_prefix(ARTIFACTS_BUCKET, f"models/{model_name}/", local_dir)
    model = PipelineModel.load(str(local_dir))
    MODEL_CACHE[model_name] = model
    return model


def persist_predictions_to_gold(rows: list, inference_id: str) -> str:
    df = pd.DataFrame(rows)
    table = pa.Table.from_pandas(df, schema=PREDICTION_SCHEMA, preserve_index=False)
    buf = io.BytesIO()
    pq.write_table(table, buf, compression="snappy")
    buf.seek(0)
    key = f"{PREDICCIONES_PREFIX.rstrip('/')}/inference_{inference_id}.parquet"
    s3.put_object(Bucket=GOLD_BUCKET, Key=key, Body=buf.getvalue())
    return f"s3://{GOLD_BUCKET}/{key}"


@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok", "engine": "spark-mllib", "loaded_models": list(MODEL_CACHE.keys())}), 200


@app.route("/invocations", methods=["POST"])
def invocations():
    payload = request.get_json(force=True, silent=True) or {}
    models = payload.get("models") or [payload.get("modelo", "gbt_regressor")]
    records = payload.get("records", [])
    persist = bool(payload.get("persist_to_gold", False))

    if not records:
        return jsonify({"error": "Provide a non-empty 'records' list."}), 400

    spark = get_spark()
    inference_id = uuid.uuid4().hex[:12]
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    sdf = spark.createDataFrame(pd.DataFrame(records))
    results = []

    for model_spec in models:
        if isinstance(model_spec, dict):
            model_name = model_spec["modelo"]
            autor = model_spec.get("autor", "equipo")
        else:
            model_name = str(model_spec)
            autor = payload.get("autor", "equipo")

        model = load_spark_model(model_name)
        scored = model.transform(sdf).select("prediction").toPandas()["prediction"].tolist()

        for rec, pred in zip(records, scored):
            vel_origen = float(rec.get("vel_origen_mbps", rec.get("vel_t", rec.get("vel_descarga_mbps", 0.0))))
            pred_val = float(pred)
            results.append({
                "inference_id": inference_id,
                "inference_timestamp": now,
                "modelo": model_name,
                "autor": autor,
                "ubigeo": str(rec.get("ubigeo", "")).zfill(6),
                "year_objetivo": int(rec.get("year_objetivo", 2026)),
                "quarter_objetivo": int(rec.get("quarter_objetivo", 2)),
                "vel_origen_mbps": vel_origen,
                "pred_descarga_mbps": pred_val,
                "indice_prioridad": float(rec.get("indice_prioridad", max(0.0, 100.0 - pred_val))),
            })

    gold_uri = None
    if persist and GOLD_BUCKET and results:
        gold_uri = persist_predictions_to_gold(results, inference_id)

    for r in results:
        r["inference_timestamp"] = r["inference_timestamp"].isoformat() + "Z"

    return jsonify({
        "inference_id": inference_id,
        "count": len(results),
        "gold_uri": gold_uri,
        "predictions": results,
    }), 200
