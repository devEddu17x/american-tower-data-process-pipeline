"""Contratos y validaciones independientes de AWS y Spark."""

import hashlib
import json
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import PurePosixPath
from urllib.parse import urlparse

PERIODS = tuple(
    f"{year}Q{quarter}"
    for year in range(2019, 2027)
    for quarter in range(1, 5)
    if (year, quarter) <= (2026, 1)
)
SOURCES = frozenset(
    {"ookla", "osiptel_cobertura", "osiptel_estaciones", "inei", "worldpop"}
)
SUCCESS_STATUSES = frozenset({"verified", "reused_verified"})


def utc():
    return datetime.now(timezone.utc).isoformat()


def canonical(value):
    return json.dumps(
        value,
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
        allow_nan=False,
    ).encode()


def fingerprint(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def s3_parts(uri):
    parsed = urlparse(uri)
    if (
        parsed.scheme != "s3"
        or not parsed.netloc
        or not parsed.path.strip("/")
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError("Se requiere una URI s3://bucket/key sin parámetros")
    return parsed.netloc, parsed.path.lstrip("/")


def safe_component(value):
    if (
        not isinstance(value, str)
        or not value.strip()
        or value in {".", ".."}
        or any(c in value for c in "/\\\x00\n\r")
    ):
        raise ValueError("Componente de ruta inválido")
    return value


@dataclass(frozen=True)
class Settings:
    buckets: dict
    inputs: dict
    region: str = "us-east-1"
    periods: tuple = PERIODS
    max_file_bytes: int = 2 * 1024**3
    max_total_bytes: int = 32 * 1024**3
    min_free_bytes: int = 2 * 1024**3
    max_entries: int = 10000
    batch_size: int = 100
    transfer_partitions: int = 10
    cache_root: str = "/mnt/american-tower-bronze"
    inei_layer: str = "DISTRITO"
    provenance: dict = field(default_factory=dict)

    @classmethod
    def from_dict(cls, value):
        parameters = dict(value)
        if "periods" in parameters:
            parameters["periods"] = tuple(parameters["periods"])
        settings = cls(**parameters)
        settings.validate()
        return settings

    def validate(self):
        zones = {"bronze", "silver", "gold", "operations", "artifacts"}
        if set(self.buckets) != zones or len(set(self.buckets.values())) != 5:
            raise ValueError("Se requieren cinco buckets distintos")
        if any(
            not re.fullmatch(r"[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]", b)
            for b in self.buckets.values()
        ):
            raise ValueError("Nombres de buckets incompletos o inválidos")
        if self.region != "us-east-1" or self.periods != PERIODS:
            raise ValueError(
                "El contrato requiere us-east-1 y 29 trimestres 2019Q1–2026Q1"
            )
        if self.transfer_partitions != 10:
            raise ValueError("La topología acordada requiere diez particiones")
        if not 1 <= self.batch_size <= 1200:
            raise ValueError("Tamaño de lote fuera de rango")
        if any(
            v <= 0
            for v in [
                self.max_file_bytes,
                self.max_total_bytes,
                self.min_free_bytes,
                self.max_entries,
            ]
        ):
            raise ValueError("Los límites deben ser positivos")
        for source in ("osiptel_cobertura", "osiptel_estaciones"):
            if not self.inputs.get(source):
                raise ValueError(f"Falta la entrada {source}")
            declaration = self.provenance.get(source, {})
            if urlparse(declaration.get("source_url", "")).scheme != "https":
                raise ValueError(f"Falta la fuente institucional HTTPS de {source}")
            downloaded_at = declaration.get("downloaded_at")
            direct_https = urlparse(self.inputs[source]).scheme == "https"
            audited_original = (
                declaration.get("original_download_date_unknown") is True
                and re.fullmatch(
                    r"[0-9a-f]{64}", declaration.get("original_sha256", "")
                )
                and bool(declaration.get("acquisition_note"))
            )
            if downloaded_at is None and (direct_https or audited_original):
                # La transferencia registra el instante real; no se anticipa una descarga.
                date = None
            elif not isinstance(downloaded_at, str) or not downloaded_at:
                raise ValueError(f"Falta la fecha real de obtención de {source}")
            else:
                date = datetime.fromisoformat(downloaded_at.replace("Z", "+00:00"))
            if date is not None and date.tzinfo is None:
                raise ValueError("La fecha real de obtención debe incluir zona horaria")
            if declaration.get("observation_period") and not declaration.get(
                "period_evidence"
            ):
                raise ValueError("El período observado requiere evidencia")


def entry(source, locator, name, *, kind="data", period=None, **metadata):
    if source not in SOURCES or kind not in {"data", "metadata"}:
        raise ValueError("Fuente o tipo inválido")
    safe_component(name)
    parsed = urlparse(locator)
    if parsed.scheme not in {"https", "s3", ""}:
        raise ValueError("Solo se admiten HTTPS, S3 o archivos locales del primario")
    if parsed.scheme == "s3":
        s3_parts(locator)
    return {
        "source": source,
        "locator": locator,
        "original_name": name,
        "kind": kind,
        "period": period,
        **metadata,
    }


def assign_targets(entries, buckets):
    """Agrupa cada versión por fuente y evita colisiones entre originales."""
    identities = [fingerprint(row) for row in entries]
    if len(set(identities)) != len(identities):
        raise ValueError("Inventario duplicado")
    snapshots = {
        source: fingerprint(
            sorted(
                identity
                for identity, row in zip(identities, entries)
                if row["source"] == source
            )
        )
        for source in SOURCES
    }
    assigned = []
    for identity, row in zip(identities, entries):
        source = row["source"]
        prefix = f"{source}/snapshot_id={snapshots[source]}"
        suffix = [row["kind"], identity, row["original_name"]]
        assigned.append(
            {
                **row,
                "entry_id": identity,
                "snapshot_id": snapshots[source],
                "bucket": buckets["bronze"],
                "key": str(PurePosixPath(prefix, *suffix)),
            }
        )
    return assigned


def validate_inventory(entries, settings):
    if not entries or len(entries) > settings.max_entries:
        raise ValueError("Inventario vacío o excesivo")
    if any(
        row["source"] not in SOURCES or row["kind"] not in {"data", "metadata"}
        for row in entries
    ):
        raise ValueError("El inventario contiene una fuente fuera del alcance activo")
    present = {e["source"] for e in entries if e["kind"] == "data"}
    if present != SOURCES:
        raise ValueError(f"Fuentes faltantes: {sorted(SOURCES - present)}")
    ookla_periods = {
        e["period"] for e in entries if e["source"] == "ookla" and e["kind"] == "data"
    }
    if ookla_periods != set(settings.periods):
        raise ValueError("Historia Ookla incompleta")
    inei_layers = [
        e.get("level") for e in entries if e["source"] == "inei" and e["kind"] == "data"
    ]
    if sorted(inei_layers) != ["departamento", "distrito", "provincia"]:
        raise ValueError("INEI requiere las tres capas originales")
    for row in entries:
        if (
            row["source"] == "ookla"
            and row["kind"] == "data"
            and "/type=mobile/" not in row["locator"]
        ):
            raise ValueError("Ookla debe utilizar únicamente la capa móvil")
        if (
            not row.get("planned_bytes")
            or row["planned_bytes"] > settings.max_file_bytes
        ):
            raise ValueError("Entrada sin tamaño comprobado o fuera del límite")
    if sum(e["planned_bytes"] for e in entries) > settings.max_total_bytes:
        raise ValueError("El plan supera el límite total explícito")


def reconcile(entries, receipts):
    expected = {e["entry_id"]: e for e in entries}
    ids = [r["entry_id"] for r in receipts]
    if len(ids) != len(set(ids)) or set(ids) != set(expected):
        raise ValueError("Recibos duplicados, faltantes o ajenos al plan")
    for receipt in receipts:
        row = expected[receipt["entry_id"]]
        if receipt["status"] not in SUCCESS_STATUSES:
            raise ValueError("Existen objetos rechazados")
        if receipt["bytes"] != row["planned_bytes"]:
            raise ValueError("Bytes distintos del plan")
        if (receipt["bucket"], receipt["key"]) != (row["bucket"], row["key"]):
            raise ValueError("Destino distinto del plan")
        if not re.fullmatch(r"[0-9a-f]{64}", receipt["sha256"]):
            raise ValueError("SHA-256 inválido")
    return sum(r["bytes"] for r in receipts)
