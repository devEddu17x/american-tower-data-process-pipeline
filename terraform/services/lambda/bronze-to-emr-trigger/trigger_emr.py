import json
import os
import urllib.parse

import boto3

emr = boto3.client("emr")


def find_active_cluster(prefix: str):
    paginator = emr.get_paginator("list_clusters")
    for page in paginator.paginate(ClusterStates=["RUNNING", "WAITING"]):
        for cluster in page.get("Clusters", []):
            if cluster["Name"].startswith(prefix):
                return cluster["Id"], cluster["Name"]
    return None, None


def handler(event, context):
    cluster_prefix = os.environ["EMR_CLUSTER_NAME_PREFIX"]
    script_s3_uri = os.environ["INCREMENTAL_SCRIPT_S3_URI"]
    bronze_manifest_uri = os.environ["BRONZE_MANIFEST_URI"]
    silver_manifest_uri = os.environ["SILVER_MANIFEST_URI"]
    silver_bucket = os.environ["SILVER_BUCKET"]
    gold_bucket = os.environ["GOLD_BUCKET"]
    gold_run_id = os.environ["GOLD_RUN_ID"]
    operations_bucket = os.environ["OPERATIONS_BUCKET"]
    region = os.environ.get("AWS_REGION", "us-east-1")
    quicksight_dataset_id = os.environ.get("QUICKSIGHT_DATASET_ID", "")

    records = event.get("Records", [])
    if not records:
        return {"status": "ignored", "reason": "no_records"}

    cluster_id, cluster_name = find_active_cluster(cluster_prefix)
    if not cluster_id:
        print(f"[INFO] No active EMR cluster found with prefix '{cluster_prefix}'. Skipping trigger.")
        return {"status": "skipped", "reason": "no_active_emr_cluster"}

    submitted = []
    for rec in records:
        bucket = rec["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(rec["s3"]["object"]["key"])
        if not key.endswith(".parquet"):
            continue

        input_uri = f"s3://{bucket}/{key}"
        filename = key.rsplit("/", 1)[-1]

        cmd = (
            "PYSPARK_PYTHON=/opt/american-tower/venv/bin/python "
            "PYSPARK_DRIVER_PYTHON=/opt/american-tower/venv/bin/python "
            "spark-submit --master yarn --deploy-mode client "
            "--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=/opt/american-tower/venv/bin/python "
            "--conf spark.executorEnv.PYSPARK_PYTHON=/opt/american-tower/venv/bin/python "
            f"{script_s3_uri} "
            f"--input-uri '{input_uri}' "
            f"--bronze-manifest-uri '{bronze_manifest_uri}' "
            f"--silver-manifest-uri '{silver_manifest_uri}' "
            f"--silver-bucket '{silver_bucket}' "
            f"--gold-bucket '{gold_bucket}' "
            f"--gold-run-id '{gold_run_id}' "
            f"--operations-bucket '{operations_bucket}' "
            f"--region '{region}' "
            f"--quicksight-dataset-id '{quicksight_dataset_id}'"
        )

        resp = emr.add_job_flow_steps(
            JobFlowId=cluster_id,
            Steps=[
                {
                    "Name": f"Incremental Ookla {filename}",
                    "ActionOnFailure": "CONTINUE",
                    "HadoopJarStep": {
                        "Jar": "command-runner.jar",
                        "Args": ["bash", "-lc", cmd],
                    },
                }
            ],
        )
        step_id = resp["StepIds"][0]
        print(f"[INFO] Submitted EMR step {step_id} on {cluster_id} ({cluster_name}) for {input_uri}")
        submitted.append({"input_uri": input_uri, "cluster_id": cluster_id, "step_id": step_id})

    return {"status": "submitted", "steps": submitted}
