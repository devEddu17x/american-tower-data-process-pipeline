"""
SageMaker Serverless CPU Inference Service (Multi-Model Contract).

Implements SageMaker's /ping and /invocations HTTP endpoints on port 8080.
Ready to load up to 4 team models from s3://<ARTIFACTS_BUCKET>/models/<model_name>/model.joblib
and optionally persist predictions to s3://<GOLD_BUCKET>/predicciones_modelos/
for live QuickSight DIRECT_QUERY visualization.
"""

import io
import os
import uuid
from datetime import datetime, timezone

import boto3
import joblib
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from flask import Flask, jsonify, request

app = Flask(__name__)

REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
ARTIFACTS_BUCKET = os.environ.get("ARTIFACTS_BUCKET", "")
GOLD_BUCKET = os.environ.get("GOLD_BUCKET", "")
PREDICCIONES_PREFIX = os.environ.get("PREDICCIONES_PREFIX", "predicciones_modelos/")

s3 = boto3.client("s3", region_name=REGION)
MODEL_CACHE = {}

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


def load_model(model_name: str):
    """Lazy-loads a serialized joblib model from S3 artifacts/models/<model_name>/model.joblib."""
    if model_name in MODEL_CACHE:
        return MODEL_CACHE[model_name]
    if not ARTIFACTS_BUCKET:
        raise RuntimeError("ARTIFACTS_BUCKET environment variable is not configured.")
    key = f"models/{model_name}/model.joblib"
    buf = io.BytesIO()
    s3.download_fileobj(ARTIFACTS_BUCKET, key, buf)
    buf.seek(0)
    model = joblib.load(buf)
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
    return jsonify({"status": "ok", "loaded_models": list(MODEL_CACHE.keys())}), 200


@app.route("/invocations", methods=["POST"])
def invocations():
    payload = request.get_json(force=True, silent=True) or {}
    models = payload.get("models") or [payload.get("modelo", "modelo_base")]
    records = payload.get("records", [])
    persist = bool(payload.get("persist_to_gold", False))

    if not records:
        return jsonify({"error": "Provide a non-empty 'records' list."}), 400

    inference_id = uuid.uuid4().hex[:12]
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    input_df = pd.DataFrame(records)
    results = []

    for model_spec in models:
        if isinstance(model_spec, dict):
            model_name = model_spec["modelo"]
            autor = model_spec.get("autor", "equipo")
            feature_cols = model_spec.get("features")
        else:
            model_name = str(model_spec)
            autor = payload.get("autor", "equipo")
            feature_cols = payload.get("features")

        model = load_model(model_name)
        x = input_df[feature_cols] if feature_cols else input_df
        preds = model.predict(x)

        for rec, pred in zip(records, preds):
            vel_origen = float(rec.get("vel_origen_mbps", rec.get("vel_descarga_mbps", 0.0)))
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
