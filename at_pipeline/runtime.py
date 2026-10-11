"""Orquestación EMR, recibos duraderos y publicación tras conciliación."""

import json
import os
import socket
import sys
import tempfile
import time
import uuid
import zipfile
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from dataclasses import asdict
from pathlib import Path

from . import REVISION
from .contracts import (
    SUCCESS_STATUSES,
    Settings,
    canonical,
    fingerprint,
    reconcile,
    s3_parts,
    utc,
    validate_inventory,
)
from .local import cache_directory
from .observability import logged_phase, logger
from .storage import Storage, digest_file, validate_file

PYTHON_ENV = "/opt/american-tower/venv/bin/python"
EXPECTED_PACKAGES = {
    "apache-sedona": "1.7.2",
    "geopandas": "1.0.1",
    "rasterio": "1.3.11",
    "shapely": "2.0.6",
    "pyproj": "3.6.1",
    "pyarrow": "17.0.0",
    "openpyxl": "3.1.5",
}


def bundle_code(package_root, destination):
    files = sorted(Path(package_root).glob("*.py"))
    code_sha256 = fingerprint({file.name: file.read_text() for file in files})
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in files:
            info = zipfile.ZipInfo("at_pipeline/" + file.name)
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, file.read_bytes())
    return code_sha256


@logged_phase("distribución del paquete Python")
def distribute_code(package_root, settings, storage, spark, run_id):
    """Conserva el ZIP del driver mientras los executors pueden solicitarlo."""
    directory = cache_directory(settings.cache_root) / run_id / "code"
    directory.mkdir(parents=True, exist_ok=True)
    pending = directory / "at_pipeline.pending.zip"
    code_sha256 = bundle_code(package_root, pending)
    archive = pending.replace(directory / f"at_pipeline_{code_sha256}.zip")
    archive_sha256 = digest_file(archive)
    key = f"evidence/run_id={run_id}/code/at_pipeline.zip"
    storage.upload_verified(
        archive, settings.buckets["operations"], key, archive_sha256
    )
    # addPyFile registra el origen; la descarga de cada executor puede ser posterior.
    # No se elimina ni se usa un TemporaryDirectory para este archivo.
    spark.sparkContext.addPyFile(str(archive))
    return {
        "code_sha256": code_sha256,
        "archive_path": str(archive),
        "archive_sha256": archive_sha256,
        "archive_uri": f"s3://{settings.buckets['operations']}/{key}",
    }


def object_identities(objects):
    return sorted((row["entry_id"], row["bytes"], row["sha256"]) for row in objects)


@logged_phase("creación de la sesión Spark")
def create_spark(settings):
    if sys.executable != PYTHON_ENV:
        raise RuntimeError(f"Se requiere el kernel American Tower: {PYTHON_ENV}")
    home = Path("/usr/lib/spark")
    py4j = sorted((home / "python/lib").glob("py4j-*.zip"))
    if not py4j:
        raise RuntimeError("No se encontró Py4J del Spark instalado en EMR")
    os.environ.update(
        SPARK_HOME=str(home),
        PYSPARK_PYTHON=PYTHON_ENV,
        PYSPARK_DRIVER_PYTHON=PYTHON_ENV,
    )
    for path in (home / "python", py4j[0]):
        sys.path.insert(0, str(path))
    from pyspark import SparkContext
    from pyspark.sql import SparkSession

    if SparkContext._active_spark_context is not None:
        raise RuntimeError(
            "Se requiere un kernel nuevo para aplicar recursos y distribuir código"
        )
    event_root = f"s3://{settings.buckets['operations']}/evidence/spark-events/"
    storage = Storage(settings.region)
    try:
        storage.s3.put_object(
            Bucket=settings.buckets["operations"],
            Key="evidence/spark-events/",
            Body=b"",
        )
    finally:
        storage.close()
    builder = (
        SparkSession.builder.master("yarn")
        .appName("american-tower-bronze-five-sources")
        .config("spark.submit.deployMode", "client")
        .config("spark.executor.instances", "10")
        .config("spark.executor.cores", "4")
        .config("spark.task.cpus", "4")
        .config("spark.executor.memory", "9g")
        .config("spark.executor.memoryOverhead", "2g")
        .config("spark.dynamicAllocation.enabled", "false")
        .config("spark.speculation", "false")
        .config("spark.yarn.am.memory", "512m")
        .config("spark.yarn.am.memoryOverhead", "512m")
        .config("spark.sql.shuffle.partitions", "80")
        .config("spark.default.parallelism", "80")
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.pyspark.python", PYTHON_ENV)
        .config("spark.pyspark.driver.python", PYTHON_ENV)
        .config("spark.executorEnv.PYSPARK_PYTHON", PYTHON_ENV)
        .config("spark.eventLog.enabled", "true")
        .config("spark.eventLog.dir", event_root)
    )
    return builder.getOrCreate()


def collect_progress(sc, rdd, label, interval=15):
    group = f"{label}-{uuid.uuid4().hex}"
    pool = ThreadPoolExecutor(max_workers=1)

    def collect():
        sc.setJobGroup(group, label, interruptOnCancel=True)
        try:
            return rdd.collect()
        finally:
            sc.setLocalProperty("spark.jobGroup.id", None)

    future = pool.submit(collect)
    started = time.perf_counter()
    logger.info("Inicio de %s; Spark application=%s", label, sc.applicationId)
    try:
        while True:
            try:
                result = future.result(timeout=interval)
                logger.info(
                    "Fin de %s: %d resultados; %.1f s",
                    label,
                    len(result),
                    time.perf_counter() - started,
                )
                return result
            except TimeoutError:
                tracker = sc.statusTracker()
                jobs = tracker.getJobIdsForGroup(group)
                stages = []
                for job_id in jobs:
                    job = tracker.getJobInfo(job_id)
                    if job is not None:
                        for stage_id in job.stageIds:
                            stage = tracker.getStageInfo(stage_id)
                            if stage is not None:
                                stages.append(
                                    f"{stage_id}: {stage.numCompletedTasks}/{stage.numTasks} tareas; activas={stage.numActiveTasks}; fallidas={stage.numFailedTasks}"
                                )
                logger.info(
                    "%s: %.1f s; trabajos=%s; etapas=%s",
                    label,
                    time.perf_counter() - started,
                    list(jobs),
                    "; ".join(stages),
                )
    except BaseException as exc:
        logger.error("%s falló (%s)", label, type(exc).__name__)
        sc.cancelJobGroup(group)
        raise
    finally:
        pool.shutdown(wait=False)


def probe_worker(job):
    import shutil
    from importlib import import_module
    from importlib.metadata import version

    # Imports reales comprueban la carga de extensiones binarias en cada nodo.
    for package in (
        "geopandas",
        "rasterio",
        "shapely",
        "pyproj",
        "pyarrow",
        "openpyxl",
    ):
        import_module(package)

    settings, run_id = Settings.from_dict(job["settings"]), job["run_id"]
    root = cache_directory(settings.cache_root)
    packages = {name: version(name) for name in EXPECTED_PACKAGES}
    if packages != EXPECTED_PACKAGES or sys.executable != PYTHON_ENV:
        raise RuntimeError("Dependencias o Python distintos del perfil de bootstrap")
    if shutil.disk_usage(root).free < settings.max_file_bytes + settings.min_free_bytes:
        raise RuntimeError("Disco insuficiente en un trabajador")
    storage = Storage(settings.region)
    try:
        host = socket.gethostname()
        for zone in ("bronze", "operations"):
            key = f"_diagnostics/run_id={run_id}/{host}/{zone}.json"
            storage.put_json(settings.buckets[zone], key, {"host": host})
            if storage.get_json(settings.buckets[zone], key) != {"host": host}:
                raise RuntimeError("Prueba de escritura/lectura S3 inválida")
        return {
            "status": "verified",
            "host": host,
            "python": sys.executable,
            "cache_root": str(root),
            "packages": packages,
            "free_bytes": shutil.disk_usage(root).free,
        }
    finally:
        storage.close()


def probe_partition(iterator):
    from pyspark import BarrierTaskContext

    try:
        jobs = list(iterator)
        if len(jobs) != 1:
            raise ValueError("Cada partición de verificación requiere un trabajo")
        sample = probe_worker(jobs[0])
    except Exception as exc:  # noqa: BLE001 -- se devuelve el rechazo al driver
        sample = {
            "status": "failed",
            "host": socket.gethostname(),
            "python": sys.executable,
            "error_type": type(exc).__name__,
            "reason": str(exc)[:2000],
        }
    # Todos los workers llegan a la barrera, incluso si una comprobación falla.
    # La corrida sigue bloqueada; el driver registra y muestra los rechazos.
    BarrierTaskContext.get().barrier()
    yield sample


def validate_worker_samples(samples, report_uri):
    failed = [sample for sample in samples if sample["status"] != "verified"]
    if failed:
        details = "\n".join(
            f"{sample['host']}: {sample['error_type']}: {sample['reason']}"
            for sample in failed
        )
        raise RuntimeError(
            f"Verificación de workers rechazada:\n{details}\n{report_uri}"
        )
    if len(samples) != 10 or len({sample["host"] for sample in samples}) != 10:
        raise RuntimeError(
            f"La prueba simultánea no observó diez hosts distintos. {report_uri}"
        )


class Transfer:
    def __init__(self, settings, storage, plan, run_id, previous_run=None):
        self.settings, self.storage, self.plan, self.run_id = (
            settings,
            storage,
            plan,
            run_id,
        )
        self.previous_run = previous_run
        self.prefix = f"evidence/run_id={run_id}"

    def reuse(self, row):
        if not self.previous_run:
            return None
        key = f"evidence/run_id={self.previous_run}/verified/{row['entry_id']}.json"
        previous = self.storage.get_json(
            self.settings.buckets["operations"], key, optional=True
        )
        if not previous:
            return None
        if previous.get("status") not in SUCCESS_STATUSES or (
            previous.get("bucket"),
            previous.get("key"),
        ) != (row["bucket"], row["key"]):
            raise ValueError("Recibo anterior no corresponde al destino planificado")
        current = self.storage.digest_object(
            row["bucket"], row["key"], previous.get("version_id")
        )
        if current != (previous["sha256"], row["planned_bytes"]):
            raise ValueError("El objeto de la corrida anterior perdió integridad")
        return {
            **previous,
            "status": "reused_verified",
            "resumed_from": self.previous_run,
        }

    def one(self, row):
        started = time.perf_counter()
        receipt = {
            "entry_id": row["entry_id"],
            "source": row["source"],
            "run_id": self.run_id,
            "status": "failed",
            "started_at": utc(),
            "worker_host": socket.gethostname(),
        }
        root = cache_directory(self.settings.cache_root)
        try:
            previous = self.reuse(row)
            if previous:
                receipt.update(
                    previous, run_id=self.run_id, worker_host=socket.gethostname()
                )
            else:
                with tempfile.TemporaryDirectory(
                    prefix="transfer-", dir=root
                ) as directory:
                    path = Path(directory) / row["original_name"]
                    digest, size, observed = self.storage.download(
                        row,
                        path,
                        self.settings.max_file_bytes,
                        self.settings.min_free_bytes,
                    )
                    validate_file(path, row["original_name"])
                    downloaded_at = utc()
                    head = self.storage.upload_verified(
                        path,
                        row["bucket"],
                        row["key"],
                        digest,
                        metadata={"source": row["source"], "run-id": self.run_id},
                    )
                    receipt.update(
                        status="verified",
                        downloaded_at=downloaded_at,
                        bytes=size,
                        sha256=digest,
                        bucket=row["bucket"],
                        key=row["key"],
                        version_id=head.get("VersionId"),
                        sse=head.get("ServerSideEncryption"),
                        source_headers=observed,
                    )
        except Exception as exc:  # noqa: BLE001 -- cada rechazo se registra sin detener los otros archivos
            # La evidencia no incluye URLs firmadas, credenciales ni cuerpos de respuesta.
            receipt.update(status="failed", error_type=type(exc).__name__)
            if isinstance(exc, (ValueError, RuntimeError)):
                receipt["reason"] = str(exc)[:300]
            quarantine = f"quarantine/{row['source']}/run_id={self.run_id}/{row['entry_id']}/rejection.json"
            self.storage.put_json(
                self.settings.buckets["operations"], quarantine, receipt
            )
        receipt.update(
            finished_at=utc(), seconds=round(time.perf_counter() - started, 3)
        )
        attempt = uuid.uuid4().hex
        self.storage.put_json(
            self.settings.buckets["operations"],
            f"{self.prefix}/receipts/{row['entry_id']}/{attempt}.json",
            receipt,
        )
        if receipt["status"] in SUCCESS_STATUSES:
            self.storage.put_json(
                self.settings.buckets["operations"],
                f"{self.prefix}/verified/{row['entry_id']}.json",
                receipt,
            )
        return receipt


def transfer_partition(iterator):
    import fcntl

    storage = Storage()
    try:
        for job in iterator:
            settings = Settings.from_dict(job["settings"])
            transfer = Transfer(
                settings, storage, job["plan"], job["run_id"], job.get("previous_run")
            )
            # Serializa payloads que comparten caché durante reintentos de Spark.
            root = cache_directory(settings.cache_root)
            with (root / "transfer.lock").open("a") as lock:
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
                try:
                    yield transfer.one(job["entry"])
                finally:
                    fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
    finally:
        storage.close()


class BronzeRun:
    def __init__(self, settings, spark, storage, run_id, code_sha256):
        self.settings, self.spark, self.storage = settings, spark, storage
        self.run_id, self.code_sha256 = run_id, code_sha256
        self.prefix = f"evidence/run_id={run_id}"
        self.previous_run = None
        self.account_id = None
        self.plan = None
        self.receipts = None

    @logged_phase("verificación de la plataforma observada")
    def preflight(self):
        metadata = Path("/mnt/var/lib/info/job-flow.json")
        instance_info = Path("/mnt/var/lib/info/instance.json")
        if (
            not metadata.is_file()
            or not instance_info.is_file()
            or json.loads(instance_info.read_text()).get("isMaster") is not True
        ):
            raise RuntimeError("La notebook debe ejecutarse en el nodo primario EMR")
        cluster_id = json.loads(metadata.read_text())["jobFlowId"]
        logger.info("Validación del clúster EMR %s", cluster_id)
        identity = self.storage.session.client("sts").get_caller_identity()
        emr = self.storage.session.client("emr")
        cluster = emr.describe_cluster(ClusterId=cluster_id)["Cluster"]
        groups = [
            group
            for page in emr.get_paginator("list_instance_groups").paginate(
                ClusterId=cluster_id
            )
            for group in page["InstanceGroups"]
        ]
        expected = {
            "MASTER": (1, "ON_DEMAND"),
            "CORE": (2, "ON_DEMAND"),
            "TASK": (8, "SPOT"),
        }
        observed = {}
        for role, (count, market) in expected.items():
            selected = [group for group in groups if group["InstanceGroupType"] == role]
            actual = sum(group["RunningInstanceCount"] for group in selected)
            if actual != count or any(
                group["InstanceType"] != "m5.xlarge" or group["Market"] != market
                for group in selected
            ):
                raise RuntimeError(f"Topología EMR distinta del contrato para {role}")
            observed[role] = {"running": actual, "type": "m5.xlarge", "market": market}
        if cluster["ReleaseLabel"] != "emr-7.1.0" or not self.spark.version.startswith(
            "3.5.0"
        ):
            raise RuntimeError("Release EMR o Spark distintos del contrato")
        for bucket in (
            self.settings.buckets[zone] for zone in ("bronze", "operations")
        ):
            logger.info("Validación de acceso y región del bucket %s", bucket)
            self.storage.s3.head_bucket(Bucket=bucket)
            location = (
                self.storage.s3.get_bucket_location(Bucket=bucket)["LocationConstraint"]
                or "us-east-1"
            )
            if location != self.settings.region:
                raise RuntimeError("Un bucket está fuera de us-east-1")
        jobs = [
            {"settings": asdict(self.settings), "run_id": self.run_id}
            for _ in range(10)
        ]
        samples = collect_progress(
            self.spark.sparkContext,
            self.spark.sparkContext.parallelize(jobs, 10)
            .barrier()
            .mapPartitions(probe_partition),
            "preflight_diez_workers",
        )
        report = {
            "cluster_id": cluster_id,
            "account_id": identity["Account"],
            "topology": observed,
            "spark_application_id": self.spark.sparkContext.applicationId,
            "spark_version": self.spark.version,
            "worker_samples": samples,
            "at": utc(),
        }
        self.storage.put_json(
            self.settings.buckets["operations"],
            self.prefix + "/environment.json",
            report,
        )
        report_uri = (
            f"s3://{self.settings.buckets['operations']}/{self.prefix}/environment.json"
        )
        validate_worker_samples(samples, report_uri)
        for sample in samples:
            logger.info(
                "Worker verificado: host=%s; cache=%s; libre=%.2f GiB",
                sample["host"],
                sample["cache_root"],
                sample["free_bytes"] / 1024**3,
            )
        self.account_id = identity["Account"]
        self.storage.put_json(
            self.settings.buckets["operations"],
            self.prefix + "/config.json",
            asdict(self.settings),
        )
        return report

    @logged_phase("reanudación del plan congelado")
    def load_plan(self, uri):
        bucket, key = s3_parts(uri)
        logger.info("Lectura del plan desde s3://%s/%s", bucket, key)
        if bucket != self.settings.buckets["operations"]:
            raise ValueError("El plan debe pertenecer al bucket Operations configurado")
        plan = self.storage.get_json(bucket, key)
        digest = fingerprint({k: v for k, v in plan.items() if k != "plan_id"})
        if (
            plan["plan_id"] != digest
            or plan["revision"] != REVISION
            or plan["code_sha256"] != self.code_sha256
        ):
            raise ValueError("Plan corrupto o incompatible con esta implementación")
        saved_settings = Settings.from_dict(plan["settings"])
        if (
            saved_settings.buckets != self.settings.buckets
            or plan.get("account_id") != self.account_id
        ):
            raise ValueError("Cuenta o buckets distintos del plan congelado")
        validate_inventory(plan["entries"], saved_settings)
        self.settings = saved_settings
        self.previous_run = plan["run_id"]
        self.plan = plan
        logger.info(
            "Plan reanudado: corrida=%s; objetos=%d; %.3f GiB; se omiten las consultas de fuentes",
            self.previous_run,
            len(plan["entries"]),
            sum(row["planned_bytes"] for row in plan["entries"]) / 1024**3,
        )
        return plan

    def build_plan(self):
        from .planning import Planner

        if self.account_id is None:
            raise RuntimeError("El preflight debe completarse antes de planificar")

        planner = Planner(
            self.settings, self.storage, self.spark, self.run_id, self.code_sha256
        )
        self.plan = planner.build()
        self.plan["account_id"] = self.account_id
        self.plan["plan_id"] = fingerprint(
            {k: v for k, v in self.plan.items() if k != "plan_id"}
        )
        self.storage.put_json(
            self.settings.buckets["operations"], self.prefix + "/plan.json", self.plan
        )
        logger.info(
            "Plan completo persistido: objetos=%d; %.3f GiB; s3://%s/%s/plan.json",
            len(self.plan["entries"]),
            self.plan["total_bytes"] / 1024**3,
            self.settings.buckets["operations"],
            self.prefix,
        )
        return self.plan

    @logged_phase("transferencia de originales Bronze")
    def execute(self):
        if self.plan is None:
            raise RuntimeError("Falta construir o cargar el plan")
        if self.receipts is not None:
            raise RuntimeError(
                "La ejecución ya comenzó; la reanudación requiere una corrida nueva"
            )
        self.receipts = []
        # Se publica el plan de la nueva corrida antes del primer payload.
        active_plan = {
            **self.plan,
            "run_id": self.run_id,
            "resumed_from": self.previous_run,
        }
        active_plan["plan_id"] = fingerprint(
            {k: v for k, v in active_plan.items() if k != "plan_id"}
        )
        self.plan = active_plan
        self.storage.put_json(
            self.settings.buckets["operations"], self.prefix + "/plan.json", active_plan
        )
        started = time.perf_counter()
        local = [row for row in self.plan["entries"] if row["source"] != "ookla"]
        distributed = [row for row in self.plan["entries"] if row["source"] == "ookla"]
        logger.info(
            "Transferencia prevista: %d objetos institucionales; %d distribuidos; lotes de hasta %d",
            len(local),
            len(distributed),
            self.settings.batch_size,
        )

        def institutional_transfers():
            # Un cliente propio evita compartir la sesión HTTP con el driver.
            client = Storage(self.settings.region)
            received = []
            try:
                transfer = Transfer(
                    self.settings, client, self.plan, self.run_id, self.previous_run
                )
                for row in local:
                    logger.info(
                        "Transferencia institucional: fuente=%s; archivo=%s; bytes=%d",
                        row["source"],
                        row["original_name"],
                        row["planned_bytes"],
                    )
                    receipt = transfer.one(row)
                    received.append(receipt)
                    self.log_receipt(receipt)
                return received
            finally:
                client.close()

        pool = ThreadPoolExecutor(max_workers=1)
        institutional = pool.submit(institutional_transfers)
        try:
            for offset in range(0, len(distributed), self.settings.batch_size):
                batch = distributed[offset : offset + self.settings.batch_size]
                logger.info(
                    "Inicio del lote %d: %d objetos; %.3f GiB",
                    offset // self.settings.batch_size + 1,
                    len(batch),
                    sum(row["planned_bytes"] for row in batch) / 1024**3,
                )
                jobs = [
                    {
                        "settings": asdict(self.settings),
                        "run_id": self.run_id,
                        "previous_run": self.previous_run,
                        "plan": {"plan_id": self.plan["plan_id"]},
                        "entry": row,
                    }
                    for row in batch
                ]
                received = collect_progress(
                    self.spark.sparkContext,
                    self.spark.sparkContext.parallelize(jobs, 10).mapPartitions(
                        transfer_partition
                    ),
                    f"transferencia_lote_{offset // self.settings.batch_size + 1}",
                )
                self.receipts.extend(received)
                for receipt in received:
                    self.log_receipt(receipt)
                self.checkpoint(started)
            while True:
                try:
                    self.receipts.extend(institutional.result(timeout=15))
                    self.checkpoint(started)
                    break
                except TimeoutError:
                    logger.info(
                        "Ookla terminado; fuentes institucionales en curso; %.1f s",
                        time.perf_counter() - started,
                    )
            return self.receipts
        except BaseException as exc:
            self.fail(type(exc).__name__)
            raise
        finally:
            # No se deja una transferencia escribiendo después de terminar la celda.
            pool.shutdown(wait=True, cancel_futures=True)

    def checkpoint(self, started):
        summary = {
            "run_id": self.run_id,
            "expected": len(self.plan["entries"]),
            "processed": len(self.receipts),
            "failed": sum(r["status"] not in SUCCESS_STATUSES for r in self.receipts),
            "verified_bytes": sum(
                r.get("bytes", 0)
                for r in self.receipts
                if r["status"] in SUCCESS_STATUSES
            ),
            "transfer_hosts": sorted({r["worker_host"] for r in self.receipts}),
            "seconds": round(time.perf_counter() - started, 3),
            "updated_at": utc(),
        }
        self.storage.put_json(
            self.settings.buckets["operations"],
            self.prefix + "/checkpoint.json",
            summary,
        )
        logger.info(
            "Objetos %d/%d; fallos=%d; verificados=%.3f GiB; hosts=%d; %.1f s",
            summary["processed"],
            summary["expected"],
            summary["failed"],
            summary["verified_bytes"] / 1024**3,
            len(summary["transfer_hosts"]),
            summary["seconds"],
        )

    @staticmethod
    def log_receipt(receipt):
        message = "Objeto=%s fuente=%s worker=%s estado=%s bytes=%s segundos=%s"
        args = (
            receipt["entry_id"],
            receipt["source"],
            receipt["worker_host"],
            receipt["status"],
            receipt.get("bytes"),
            receipt.get("seconds"),
        )
        if receipt["status"] in SUCCESS_STATUSES:
            logger.info(message, *args)
        else:
            logger.error(message + " error=%s", *args, receipt.get("error_type"))

    def fail(self, reason):
        logger.error("Corrida %s rechazada: %s", self.run_id, reason)
        self.storage.put_json(
            self.settings.buckets["operations"],
            self.prefix + "/_FAILED.json",
            {"run_id": self.run_id, "reason": reason, "at": utc()},
        )

    @logged_phase("conciliación y publicación final")
    def publish(self):
        """El único punto que publica éxito exige conciliación Python y Spark."""
        if self.receipts is None:
            raise RuntimeError("La ingesta no se ejecutó")
        try:
            logger.info("Conciliación Python de %d recibos", len(self.receipts))
            total = reconcile(self.plan["entries"], self.receipts)
            bucket = self.settings.buckets["operations"]
            key = self.prefix + "/manifest.jsonl"
            body = b"\n".join(canonical(r) for r in self.receipts) + b"\n"
            self.storage.s3.put_object(
                Bucket=bucket, Key=key, Body=body, ContentType="application/x-ndjson"
            )
            manifest = self.spark.read.json(f"s3://{bucket}/{key}")
            logger.info(
                "Conciliación Spark del manifiesto: cantidad, IDs, estados y bytes"
            )
            from pyspark.sql import functions as F

            expected = self.spark.createDataFrame(
                [
                    {"entry_id": row["entry_id"], "planned_bytes": row["planned_bytes"]}
                    for row in self.plan["entries"]
                ]
            )
            if manifest.count() != len(self.plan["entries"]) or manifest.select(
                "entry_id"
            ).distinct().count() != len(self.plan["entries"]):
                raise ValueError("Manifiesto Spark incompleto o duplicado")
            if manifest.filter(~F.col("status").isin(*SUCCESS_STATUSES)).count() > 0:
                raise ValueError("Spark detectó objetos rechazados")
            if expected.join(manifest, "entry_id", "left_anti").count() > 0:
                raise ValueError("Spark detectó IDs faltantes")
            if (
                expected.join(manifest, "entry_id")
                .filter(F.col("bytes") != F.col("planned_bytes"))
                .count()
                > 0
            ):
                raise ValueError("Spark detectó diferencias de bytes")
            if manifest.agg(F.sum("bytes")).first()[0] != total:
                raise ValueError("La suma de bytes Spark difiere de los recibos")
            logger.info(
                "Conciliación aprobada: %d objetos; %.3f GiB",
                len(self.receipts),
                total / 1024**3,
            )
            summary = {
                "run_id": self.run_id,
                "plan_id": self.plan["plan_id"],
                "complete": True,
                "objects": len(self.receipts),
                "verified_bytes": total,
                "finished_at": utc(),
                "manifest_uri": f"s3://{bucket}/{key}",
                "code_sha256": self.code_sha256,
            }
            markers = []
            for source in sorted({row["source"] for row in self.plan["entries"]}):
                logger.info("Publicación o validación del snapshot %s", source)
                rows = [row for row in self.plan["entries"] if row["source"] == source]
                prefix = f"{source}/snapshot_id={rows[0]['snapshot_id']}"
                ids = {row["entry_id"] for row in rows}
                snapshot_manifest = {
                    **summary,
                    "source": source,
                    "objects": [r for r in self.receipts if r["entry_id"] in ids],
                }
                previous_marker = self.storage.get_json(
                    self.settings.buckets["bronze"], prefix + "/_SUCCESS", optional=True
                )
                if previous_marker:
                    previous_manifest = self.storage.get_json(
                        self.settings.buckets["bronze"], prefix + "/manifest.json"
                    )
                    if object_identities(
                        previous_manifest["objects"]
                    ) != object_identities(snapshot_manifest["objects"]):
                        raise ValueError("Conflicto en un snapshot ya publicado")
                else:
                    self.storage.put_json(
                        self.settings.buckets["bronze"],
                        prefix + "/manifest.json",
                        snapshot_manifest,
                    )
                markers.append(
                    f"s3://{self.settings.buckets['bronze']}/{prefix}/_SUCCESS"
                )
            bundle_key = self.prefix + "/bundle.json"
            bundle = {
                **summary,
                "settings": asdict(self.settings),
                "snapshots": markers,
                "objects": self.receipts,
                "success_uri": f"s3://{bucket}/{self.prefix}/_SUCCESS",
            }
            self.storage.put_json(bucket, bundle_key, bundle)
            summary["bundle_uri"] = f"s3://{bucket}/{bundle_key}"
            self.storage.put_json(bucket, self.prefix + "/summary.json", summary)
            for marker in markers:
                bronze_bucket, marker_key = s3_parts(marker)
                if not self.storage.get_json(bronze_bucket, marker_key, optional=True):
                    self.storage.put_json(bronze_bucket, marker_key, summary)
            # Este marcador de corrida es la barrera final que debe verificar el consumidor.
            self.storage.put_json(bucket, self.prefix + "/_SUCCESS", summary)
            logger.info(
                "INGESTA_COMPLETA; bundle=%s; éxito=%s",
                summary["bundle_uri"],
                bundle["success_uri"],
            )
            return summary
        except BaseException as exc:
            self.fail(type(exc).__name__)
            raise
