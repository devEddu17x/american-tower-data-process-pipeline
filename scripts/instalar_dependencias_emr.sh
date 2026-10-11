#!/usr/bin/env bash
# Ejecutar en la computadora LOCAL: bash instalar_dependencias_emr.sh
# Destinos del cluster actual; actualizar las IP si se recrea.
set -Eeuo pipefail

LOG_FILE="./instalacion-emr-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'echo "ERROR en linea $LINENO. Revisa el mensaje anterior y el log: $LOG_FILE"' ERR

SSH_ALIAS="emr-studio"
KEY_FILE="${HOME}/.ssh/american-tower-dev-key.pem"
CURRENT_TARGET="validacion local"

command -v ssh >/dev/null
if [[ ! -s "$KEY_FILE" ]]; then
    echo "No se encuentra la llave SSH local: $KEY_FILE"
    exit 1
fi

CONFIGURED_HOST=$(ssh -G "$SSH_ALIAS" 2>/dev/null | awk '$1 == "hostname" {h=$2} END {print h}')
if [[ -z "$CONFIGURED_HOST" || "$CONFIGURED_HOST" == "$SSH_ALIAS" ]]; then
    echo "El alias emr-studio no esta configurado en esta computadora."
    echo "Ejecuta primero tu script local de conexion a EMR."
    exit 1
fi

echo "Comprobando primary mediante $SSH_ALIAS..."
PRIMARY_HOST=$(ssh "$SSH_ALIAS" hostname)
if [[ "$PRIMARY_HOST" != "ip-10-0-234-80.ec2.internal" ]]; then
    echo "El alias apunta a $PRIMARY_HOST, distinto del primary esperado."
    echo "No se modifico ningun nodo. Comprueba el cluster y sus IP."
    exit 1
fi

for CURRENT_TARGET in \
    "$SSH_ALIAS" \
    hadoop@10.0.125.123 \
    hadoop@10.0.234.121 \
    hadoop@10.0.187.49
do
    emr_ssh_args=(-o ConnectTimeout=20 -o ServerAliveInterval=30)
    if [[ "$CURRENT_TARGET" != "$SSH_ALIAS" ]]; then
        emr_ssh_args+=(-J "$SSH_ALIAS" -i "$KEY_FILE" -o IdentitiesOnly=yes)
    fi

    echo "Instalando y verificando: $CURRENT_TARGET"
    ssh "${emr_ssh_args[@]}" "$CURRENT_TARGET" 'bash -se' <<'REMOTE_INSTALL'
set -euo pipefail
hostname
/usr/bin/python -c 'import sys; assert sys.version_info[:2] == (3, 9), sys.version'

if [[ ! -x /opt/american-tower/venv/bin/python ]]; then
    sudo install -d -o "$(id -un)" -g "$(id -gn)" /opt/american-tower
    /usr/bin/python -m venv /opt/american-tower/venv
fi

/opt/american-tower/venv/bin/python -m pip install \
    boto3==1.42.97 \
    requests==2.32.5 \
    numpy==1.26.4 \
    pandas==2.2.3 \
    shapely==2.0.6 \
    pyproj==3.6.1 \
    pyogrio==0.10.0 \
    geopandas==1.0.1 \
    apache-sedona==1.7.2 \
    pyarrow==17.0.0 \
    rasterio==1.3.11 \
    openpyxl==3.1.5

/opt/american-tower/venv/bin/python -m pip check

/opt/american-tower/venv/bin/python - <<'PY'
import sys
import importlib
from importlib.metadata import version

expected = {
    "boto3": "1.42.97", "requests": "2.32.5", "numpy": "1.26.4",
    "pandas": "2.2.3", "shapely": "2.0.6", "pyproj": "3.6.1",
    "pyogrio": "0.10.0", "geopandas": "1.0.1",
    "apache-sedona": "1.7.2", "pyarrow": "17.0.0",
    "rasterio": "1.3.11", "openpyxl": "3.1.5"
}
print("Python:", sys.executable)
assert sys.version_info[:2] == (3, 9), sys.version
for package, required in expected.items():
    importlib.import_module("sedona" if package == "apache-sedona" else package)
    installed = version(package)
    print(f"{package}: {installed}")
    assert installed == required, (package, installed, required)
print("OK: dependencias verificadas")
PY
REMOTE_INSTALL
    echo "Nodo completado: $CURRENT_TARGET"
done

echo "Registrando kernel en el primary..."
ssh "$SSH_ALIAS" 'bash -se' <<'REMOTE_KERNEL'
set -euo pipefail
/opt/american-tower/venv/bin/python -m pip install 'ipykernel==6.29.5'
/opt/american-tower/venv/bin/python -m pip check
/opt/american-tower/venv/bin/python -m ipykernel install \
    --user --name american-tower \
    --display-name "American Tower - Python 3.9"
/opt/american-tower/venv/bin/python - <<'PY'
import json
from pathlib import Path
spec = Path.home() / ".local/share/jupyter/kernels/american-tower/kernel.json"
data = json.loads(spec.read_text())
assert data["argv"][0] == "/opt/american-tower/venv/bin/python", data
print("OK: kernel registrado", spec)
PY
REMOTE_KERNEL

echo "COMPLETADO: primary, tres workers y kernel verificados."
echo "Log: $LOG_FILE"
echo "En VS Code selecciona /opt/american-tower/venv/bin/python y reinicia el kernel."
echo "Los JAR de Sedona se configuran en la celda de creacion de Spark."

