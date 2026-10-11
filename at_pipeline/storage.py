"""Clientes por proceso, descargas acotadas e integridad de objetos completos."""

import hashlib
import json
import shutil
import time
import zipfile
from contextlib import closing
from pathlib import Path
from urllib.parse import urlparse

import boto3
import requests
from boto3.s3.transfer import TransferConfig
from botocore import UNSIGNED
from botocore.config import Config
from botocore.exceptions import ClientError, ReadTimeoutError, ResponseStreamingError
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from .contracts import canonical, s3_parts

CHUNK = 8 * 1024**2
NOT_FOUND = {"404", "NoSuchKey", "NotFound"}


def digest_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(CHUNK), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_file(path, original_name):
    """Inspecciona contenedores originales sin transformar sus registros."""
    path = Path(path)
    size = path.stat().st_size
    if size <= 0:
        raise ValueError("Archivo vacío")
    with path.open("rb") as handle:
        first = handle.read(512)
        handle.seek(max(0, size - 4))
        last = handle.read(4)
    suffix = Path(original_name).suffix.lower()
    if suffix == ".parquet" and (first[:4] != b"PAR1" or last != b"PAR1"):
        raise ValueError("Firma Parquet inválida")
    if suffix in {".tif", ".tiff"} and first[:4] not in {
        b"II*\x00",
        b"MM\x00*",
        b"II+\x00",
        b"MM\x00+",
    }:
        raise ValueError("Firma TIFF inválida")
    if suffix == ".rar" and not first.startswith(b"Rar!"):
        raise ValueError("Firma RAR inválida")
    if suffix == ".gpkg" and not first.startswith(b"SQLite format 3\x00"):
        raise ValueError("Firma GeoPackage inválida")
    if suffix == ".csv" and (
        b"<html" in first.lower() or b"<!doctype html" in first.lower()
    ):
        raise ValueError("El CSV recibido contiene HTML")
    if suffix == ".xlsx":
        with zipfile.ZipFile(path) as archive:
            if (
                "xl/workbook.xml" not in archive.namelist()
                or archive.testzip() is not None
            ):
                raise ValueError("Contenedor XLSX inválido")
    if suffix in {".json", ".geojson"}:
        with path.open(encoding="utf-8") as handle:
            json.load(handle)
    if suffix == ".gz":
        import gzip

        with gzip.open(path, "rt", encoding="utf-8") as handle:
            for line in handle:
                if line.strip():
                    json.loads(line)
    return size


class Storage:
    def __init__(self, region="us-east-1"):
        sdk = Config(
            retries={"max_attempts": 8, "mode": "standard"},
            connect_timeout=15,
            read_timeout=120,
        )
        self.session = boto3.Session(region_name=region)
        self.s3 = self.session.client("s3", config=sdk)
        self.public = self.session.client(
            "s3",
            region_name="us-west-2",
            config=sdk.merge(Config(signature_version=UNSIGNED)),
        )
        self.http = requests.Session()
        self.http.headers.update(
            {
                "Accept-Encoding": "identity",
                "User-Agent": "AmericanTower-Academic-Bronze/Modular-1",
            }
        )
        retry = Retry(
            total=4,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "HEAD"],
        )
        self.http.mount("https://", HTTPAdapter(max_retries=retry))
        self.transfer = TransferConfig(
            multipart_threshold=64 * 1024**2,
            multipart_chunksize=64 * 1024**2,
            max_concurrency=4,
        )

    def close(self):
        self.http.close()
        self.s3.close()
        self.public.close()

    def put_json(self, bucket, key, value):
        body = canonical(value)
        if len(body) > 128 * 1024**2:
            raise ValueError("Documento de control supera 128 MiB")
        return self.s3.put_object(
            Bucket=bucket,
            Key=key,
            Body=body,
            ContentType="application/json",
        )

    def get_json(self, bucket, key, *, optional=False):
        try:
            response = self.s3.get_object(Bucket=bucket, Key=key)
        except ClientError as exc:
            if optional and exc.response["Error"]["Code"] in NOT_FOUND:
                return None
            raise
        with closing(response["Body"]) as body:
            payload = body.read(128 * 1024**2 + 1)
        if len(payload) > 128 * 1024**2:
            raise ValueError("Documento de control supera 128 MiB")
        return json.loads(payload)

    def head(self, bucket, key):
        try:
            return self.s3.head_object(Bucket=bucket, Key=key)
        except ClientError as exc:
            if exc.response["Error"]["Code"] in NOT_FOUND:
                return None
            raise

    def digest_object(self, bucket, key, version=None):
        args = {"Bucket": bucket, "Key": key}
        if version:
            args["VersionId"] = version
        response = self.s3.get_object(**args)
        count, digest = 0, hashlib.sha256()
        with closing(response["Body"]) as body:
            for block in iter(lambda: body.read(CHUNK), b""):
                digest.update(block)
                count += len(block)
        return digest.hexdigest(), count

    def inspect(self, row):
        """HEAD no disponible cae a GET Range; ambas respuestas se cierran."""
        parsed = urlparse(row["locator"])
        if not parsed.scheme:
            path = Path(row["locator"])
            return {
                **row,
                "planned_bytes": path.stat().st_size,
                "expected_sha256": digest_file(path),
            }
        if parsed.scheme == "s3":
            bucket, key = s3_parts(row["locator"])
            client = self.public if row.get("anonymous") else self.s3
            args = {"Bucket": bucket, "Key": key}
            if row.get("input_version_id"):
                args["VersionId"] = row["input_version_id"]
            head = client.head_object(**args)
            if row.get("input_etag") and row["input_etag"] != head.get("ETag"):
                raise ValueError("El ETag de origen cambió durante planificación")
            return {
                **row,
                "planned_bytes": head["ContentLength"],
                "input_version_id": head.get("VersionId"),
                "input_etag": head.get("ETag"),
            }
        with self.http.head(
            row["locator"], allow_redirects=True, timeout=(15, 60)
        ) as response:
            if response.status_code not in {403, 405, 501}:
                response.raise_for_status()
                self._https(response)
                if response.headers.get("Content-Length"):
                    return {
                        **row,
                        "planned_bytes": int(response.headers["Content-Length"]),
                        "input_etag": response.headers.get("ETag"),
                    }
        with self.http.get(
            row["locator"],
            headers={"Range": "bytes=0-0"},
            stream=True,
            timeout=(15, 60),
        ) as response:
            response.raise_for_status()
            self._https(response)
            content_range = response.headers.get("Content-Range", "")
            size = (
                content_range.rsplit("/", 1)[-1]
                if response.status_code == 206
                else response.headers.get("Content-Length")
            )
            if not size or not size.isdigit():
                raise ValueError("El proveedor no declara un tamaño verificable")
            return {
                **row,
                "planned_bytes": int(size),
                "input_etag": response.headers.get("ETag"),
            }

    @staticmethod
    def _https(response):
        if urlparse(response.url).scheme != "https":
            raise ValueError("Redirección HTTPS inválida")

    def download(self, row, path, max_bytes, min_free_bytes=0):
        for attempt in range(3):
            try:
                return self._download(row, path, max_bytes, min_free_bytes)
            except (
                requests.ConnectionError,
                requests.Timeout,
                requests.exceptions.ChunkedEncodingError,
                ReadTimeoutError,
                ResponseStreamingError,
            ):
                Path(path).unlink(missing_ok=True)
                if attempt == 2:
                    raise
                time.sleep(2**attempt)

    def _download(self, row, path, max_bytes, min_free_bytes=0):
        """Calcula SHA-256 durante la descarga y comprueba identidad congelada."""
        path = Path(path)
        reserve = row.get("planned_bytes", max_bytes) + min_free_bytes
        if shutil.disk_usage(path.parent).free < reserve:
            raise RuntimeError("Disco insuficiente para el archivo y margen de reserva")
        parsed = urlparse(row["locator"])
        if parsed.scheme == "s3":
            bucket, key = s3_parts(row["locator"])
            args = {"Bucket": bucket, "Key": key}
            if row.get("input_version_id"):
                args["VersionId"] = row["input_version_id"]
            elif row.get("input_etag"):
                args["IfMatch"] = row["input_etag"]
            client = self.public if row.get("anonymous") else self.s3
            response = client.get_object(**args)
            with closing(response["Body"]) as body:
                digest, size = self._write(
                    iter(lambda: body.read(CHUNK), b""), path, max_bytes
                )
            observed = {
                "etag": response.get("ETag"),
                "version_id": response.get("VersionId"),
            }
        elif parsed.scheme == "https":
            headers = {"If-Match": row["input_etag"]} if row.get("input_etag") else {}
            with self.http.get(
                row["locator"], headers=headers, stream=True, timeout=(15, 120)
            ) as response:
                response.raise_for_status()
                self._https(response)
                if (
                    row.get("input_etag")
                    and response.headers.get("ETag")
                    and row["input_etag"] != response.headers["ETag"]
                ):
                    raise ValueError("El proveedor cambió desde la planificación")
                digest, size = self._write(
                    response.iter_content(CHUNK), path, max_bytes
                )
                observed = {
                    "etag": response.headers.get("ETag"),
                    "last_modified": response.headers.get("Last-Modified"),
                }
        else:
            with Path(row["locator"]).open("rb") as handle:
                digest, size = self._write(
                    iter(lambda: handle.read(CHUNK), b""), path, max_bytes
                )
            observed = {"delivery_method": "local_primary"}
        if row.get("planned_bytes") is not None and size != row["planned_bytes"]:
            raise ValueError("Tamaño recibido distinto del plan")
        if row.get("expected_sha256") and digest != row["expected_sha256"]:
            raise ValueError("SHA-256 distinto del inventario")
        return digest, size, observed

    @staticmethod
    def _write(blocks, path, max_bytes):
        count, digest = 0, hashlib.sha256()
        with path.open("wb") as handle:
            for block in blocks:
                count += len(block)
                if count > max_bytes:
                    raise ValueError("Archivo supera el límite individual")
                handle.write(block)
                digest.update(block)
        return digest.hexdigest(), count

    def upload_verified(self, path, bucket, key, sha256, *, metadata=None):
        existing = self.head(bucket, key)
        if not existing:
            self.s3.upload_file(
                str(path),
                bucket,
                key,
                ExtraArgs={"Metadata": {"sha256": sha256, **(metadata or {})}},
                Config=self.transfer,
            )
            existing = self.s3.head_object(Bucket=bucket, Key=key)
        observed = self.digest_object(bucket, key, existing.get("VersionId"))
        if observed != (sha256, Path(path).stat().st_size):
            raise RuntimeError("Conflicto o corrupción en el objeto remoto")
        return existing
