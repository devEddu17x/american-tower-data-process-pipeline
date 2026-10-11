"""Mensajes visibles en la notebook y archivo local por corrida."""

import logging
import threading
import time
from contextlib import contextmanager
from functools import wraps

from .local import cache_directory
from .storage import digest_file

logger = logging.getLogger("at_pipeline")


class NotebookHandler(logging.Handler):
    def emit(self, record):
        # Se resuelve stdout al emitir, incluso si la celda activa ha cambiado.
        try:
            print(self.format(record), flush=True)
        except Exception:  # noqa: BLE001 -- comportamiento estándar de un handler
            self.handleError(record)


def configure_logging(run_id, cache_root):
    directory = cache_directory(cache_root) / run_id / "logs"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "bronze.log"
    formatter = logging.Formatter(
        f"%(asctime)sZ %(levelname)s [{run_id}] %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )
    formatter.converter = time.gmtime
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
        handler.close()
    for handler in (NotebookHandler(), logging.FileHandler(path, encoding="utf-8")):
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    logger.propagate = False
    logger.info("Logs de la corrida disponibles en %s", path)
    return path


@contextmanager
def progress(label, interval=15):
    """Emite actividad durante fases bloqueantes sin estimar avances inexistentes."""
    started = time.perf_counter()
    stopped = threading.Event()

    def heartbeat():
        while not stopped.wait(interval):
            logger.info("%s en curso; %.1f s", label, time.perf_counter() - started)

    logger.info("Inicio de %s", label)
    thread = threading.Thread(target=heartbeat, name="bronze-progress", daemon=True)
    thread.start()
    try:
        yield
    except BaseException as exc:
        logger.error(
            "%s falló (%s); %.1f s",
            label,
            type(exc).__name__,
            time.perf_counter() - started,
        )
        raise
    else:
        logger.info("Fin de %s; %.1f s", label, time.perf_counter() - started)
    finally:
        stopped.set()
        thread.join()


def logged_phase(label):
    def decorate(function):
        @wraps(function)
        def wrapped(*args, **kwargs):
            with progress(label):
                return function(*args, **kwargs)

        return wrapped

    return decorate


def persist_logs(storage, settings, run_id, path):
    """Conserva una copia al cerrar la celda sin ocultar su error principal."""
    key = f"evidence/run_id={run_id}/logs/bronze.log"
    try:
        for handler in logger.handlers:
            handler.flush()
        storage.upload_verified(
            path, settings.buckets["operations"], key, digest_file(path)
        )
    except Exception as exc:  # noqa: BLE001 -- el log no reemplaza el resultado del pipeline
        logger.warning(
            "No se pudo conservar el log en Operations (%s); copia local=%s",
            type(exc).__name__,
            path,
        )
        return None
    uri = f"s3://{settings.buckets['operations']}/{key}"
    logger.info("Copia del log conservada en %s", uri)
    return uri
