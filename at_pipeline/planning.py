"""Descubrimiento de fuentes y congelación de un plan portable en S3."""

import json
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from pathlib import Path
from urllib.parse import urlparse

from . import REVISION
from .contracts import (
    assign_targets,
    canonical,
    entry,
    fingerprint,
    utc,
    validate_inventory,
)
from .local import cache_directory
from .observability import logged_phase, logger
from .storage import digest_file

WORLDPOP = "https://data.worldpop.org/GIS/Population/Global_2000_2020/2020/PER/per_ppp_2020.tif"


class Planner:
    def __init__(self, settings, storage, spark, run_id, code_sha256):
        self.settings, self.storage, self.spark = settings, storage, spark
        self.run_id, self.code_sha256 = run_id, code_sha256
        self.prefix = f"evidence/run_id={run_id}"
        self.cache = cache_directory(settings.cache_root) / run_id / "planning"
        self.cache.mkdir(parents=True, exist_ok=True)
        self.entries = []

    def stage(
        self, path, source, kind="metadata", period=None, *, name=None, **metadata
    ):
        path = Path(path)
        sha256 = digest_file(path)
        declared = metadata.get("provenance", {}).get("original_sha256")
        if declared and declared != sha256:
            raise ValueError("El original local difiere del SHA-256 auditado")
        original_name = name or path.name
        key = f"{self.prefix}/planning_inputs/{sha256}/{original_name}"
        head = self.storage.upload_verified(
            path, self.settings.buckets["operations"], key, sha256
        )
        return entry(
            source,
            f"s3://{self.settings.buckets['operations']}/{key}",
            original_name,
            kind=kind,
            period=period,
            planned_bytes=path.stat().st_size,
            expected_sha256=sha256,
            input_version_id=head.get("VersionId"),
            input_etag=head.get("ETag"),
            **metadata,
        )

    def national_sources(self):
        logger.info("Registro de fuentes institucionales OSIPTEL, INEI y WorldPop")
        for source in ("osiptel_cobertura", "osiptel_estaciones"):
            locator = self.settings.inputs[source]
            declaration = self.settings.provenance[source]
            name = Path(urlparse(locator).path).name
            name = self.settings.inputs.get(source + "_name") or name
            self.entries.append(
                entry(
                    source,
                    locator,
                    name,
                    period=declaration.get("observation_period"),
                    publisher="OSIPTEL",
                    provenance=declaration,
                )
            )
        for level in ("Departamento", "Provincia", "Distrito"):
            locator = self.settings.inputs.get(
                "inei_" + level.lower(), f"https://ide.inei.gob.pe/files/{level}.rar"
            )
            name = Path(urlparse(locator).path).name
            self.entries.append(
                entry(
                    "inei",
                    locator,
                    name,
                    publisher="INEI",
                    level=level.lower(),
                    provenance_url="https://ide.inei.gob.pe",
                )
            )
        self.entries.append(
            entry(
                "worldpop",
                WORLDPOP,
                "per_ppp_2020.tif",
                period="2020",
                publisher="WorldPop",
                license="CC-BY-4.0",
                provenance_url="https://hub.worldpop.org/geodata/summary?id=6416",
            )
        )

    @logged_phase("descubrimiento de Ookla móvil")
    def ookla(self):
        for period in self.settings.periods:
            logger.info("Consulta Ookla móvil: %s", period)
            prefix = f"parquet/performance/type=mobile/year={period[:4]}/quarter={period[-1]}/"
            listing = []
            count = 0
            paginator = self.storage.public.get_paginator("list_objects_v2")
            for page in paginator.paginate(Bucket="ookla-open-data", Prefix=prefix):
                # El listado de proveedor se preserva sin convertir ETag en SHA-256.
                listing.append(json.loads(json.dumps(page, default=str)))
                for obj in page.get("Contents", []):
                    if obj["Key"].endswith(".parquet"):
                        count += 1
                        self.entries.append(
                            entry(
                                "ookla",
                                "s3://ookla-open-data/" + obj["Key"],
                                Path(obj["Key"]).name,
                                period=period,
                                anonymous=True,
                                planned_bytes=obj["Size"],
                                input_etag=obj["ETag"],
                                publisher="Ookla",
                                license="CC-BY-NC-SA-4.0",
                            )
                        )
            if count == 0:
                raise ValueError(f"Ookla no contiene archivos móviles para {period}")
            path = self.cache / f"ookla_listing_{period}.json"
            path.write_bytes(canonical(listing))
            self.entries.append(
                self.stage(path, "ookla", period=period, publisher="Ookla")
            )
            logger.info("Ookla %s: %d archivos Parquet", period, count)

    @logged_phase("comprobación de tamaños y congelación del inventario")
    def freeze(self):
        if len(self.entries) > self.settings.max_entries:
            raise ValueError("Inventario supera el límite de objetos")
        inspected = []
        clients = []
        thread_state = threading.local()

        def inspect(row):
            if not hasattr(thread_state, "client"):
                from .storage import Storage

                thread_state.client = Storage(self.settings.region)
                clients.append(thread_state.client)
            return thread_state.client.inspect(row)

        try:
            with ThreadPoolExecutor(max_workers=8) as pool:
                total = 0
                for offset in range(0, len(self.entries), self.settings.batch_size):
                    batch = self.entries[offset : offset + self.settings.batch_size]
                    results = list(pool.map(inspect, batch))
                    inspected.extend(results)
                    total += sum(row["planned_bytes"] for row in results)
                    if total > self.settings.max_total_bytes:
                        raise ValueError("El plan supera el límite total explícito")
                    logger.info(
                        "Preflight de tamaños: %d/%d objetos; %.3f GiB",
                        len(inspected),
                        len(self.entries),
                        total / 1024**3,
                    )
        finally:
            for client in clients:
                client.close()
        frozen = []
        for row, observed in zip(self.entries, inspected):
            if (
                row.get("planned_bytes") is not None
                and row["planned_bytes"] != observed["planned_bytes"]
            ):
                raise ValueError("Tamaño del proveedor cambió durante planificación")
            if observed["planned_bytes"] > self.settings.max_file_bytes:
                raise ValueError("Archivo planificado supera el límite individual")
            if not urlparse(observed["locator"]).scheme:
                staged = self.stage(
                    observed["locator"],
                    observed["source"],
                    observed["kind"],
                    observed["period"],
                    name=observed["original_name"],
                    provenance=observed.get("provenance"),
                )
                if staged["expected_sha256"] != observed["expected_sha256"]:
                    raise ValueError("El archivo local cambió durante congelación")
                observed = {**observed, **staged}
            frozen.append(observed)
        validate_inventory(frozen, self.settings)
        assigned = assign_targets(frozen, self.settings.buckets)
        plan = {
            "revision": REVISION,
            "code_sha256": self.code_sha256,
            "run_id": self.run_id,
            "created_at": utc(),
            "settings": asdict(self.settings),
            "entries": assigned,
            "total_bytes": sum(r["planned_bytes"] for r in assigned),
        }
        plan["plan_id"] = fingerprint(plan)
        return plan

    def build(self):
        logger.info(
            "Planificación nacional iniciada: %d trimestres", len(self.settings.periods)
        )
        self.national_sources()
        self.ookla()
        return self.freeze()
