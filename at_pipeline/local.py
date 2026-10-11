"""Caché local escribible sin modificar permisos del sistema ni requerir sudo."""

import errno
import os
import tempfile
from pathlib import Path


def cache_directory(preferred):
    """Prueba la ruta configurada, los directorios YARN y el temporal del usuario."""
    candidates = [Path(preferred)]
    candidates.extend(
        Path(directory.strip()) / "american-tower-bronze"
        for directory in os.environ.get("LOCAL_DIRS", "").split(",")
        if directory.strip()
    )
    candidates.append(
        Path(tempfile.gettempdir()) / f"american-tower-bronze-{os.getuid()}"
    )
    failures = []
    for root in dict.fromkeys(candidates):
        try:
            root.mkdir(parents=True, exist_ok=True)
            # La existencia del directorio no demuestra permiso de escritura.
            with tempfile.TemporaryFile(dir=root) as handle:
                handle.write(b"cache probe")
                handle.flush()
            return root
        except OSError as exc:
            if exc.errno not in {errno.EACCES, errno.EPERM, errno.EROFS}:
                raise
            failures.append(f"{root}: {type(exc).__name__} (errno={exc.errno})")
    raise PermissionError("No existe una caché escribible; " + "; ".join(failures))
