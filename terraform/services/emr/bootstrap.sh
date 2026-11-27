#!/usr/bin/env bash
# ==============================================================================
# EMR Cluster Bootstrap Action - American Tower Pipeline
# ==============================================================================
# Este script se ejecuta en PARALELO en todos los nodos (Master y Workers)
# como usuario hadoop con privilegios sudo antes de arrancar Hadoop/Spark.
# Argumentos:
#   $1 : Nombre del bucket de artefactos en S3 (para caché de venv)
# ==============================================================================

set -ex

INSTALL_DIR="/opt/american-tower"
VENV_DIR="${INSTALL_DIR}/venv"
ARTIFACTS_BUCKET="${1:-}"
CACHE_URI=""

if [[ -n "$ARTIFACTS_BUCKET" ]]; then
    CACHE_URI="s3://${ARTIFACTS_BUCKET}/envs/american-tower-venv.tar.gz"
fi

echo "Iniciando configuración de dependencias en $(hostname)..."

# 1. Instalar utilitarios del sistema y crear directorio base en /opt
sudo dnf install -y bsdtar
sudo mkdir -p "${INSTALL_DIR}"
sudo chown -R hadoop:hadoop "${INSTALL_DIR}"

# Detectar si el nodo actual es el Master
IS_MASTER=false
if [ -f /mnt/var/lib/info/instance.json ] && grep -q '"isMaster": true' /mnt/var/lib/info/instance.json; then
    IS_MASTER=true
elif [ -f /emr/instance-controller/lib/info/job-flow.json ] && grep -q '"isMaster": true' /emr/instance-controller/lib/info/job-flow.json; then
    IS_MASTER=true
fi

# 2. Estrategia de instalación rápida: Caché S3 -> Fallback a pip en paralelo
CACHE_RESTORED=false

if [[ -n "$CACHE_URI" ]]; then
    echo "Comprobando caché en S3: ${CACHE_URI}..."
    if aws s3 cp "${CACHE_URI}" /tmp/venv.tar.gz 2>/dev/null; then
        echo "¡Caché encontrada en S3! Descomprimiendo en ${INSTALL_DIR}..."
        tar -xzf /tmp/venv.tar.gz -C "${INSTALL_DIR}"
        rm -f /tmp/venv.tar.gz
        CACHE_RESTORED=true
        echo "Entorno virtual restaurado exitosamente desde S3."
    else
        echo "Caché no encontrada en S3. Procediendo a instalación con pip..."
    fi
fi

if [[ "$CACHE_RESTORED" = false ]]; then
    echo "Creando entorno virtual Python 3..."
    python3 -m venv "${VENV_DIR}"

    echo "Instalando herramientas base de empaquetado..."
    "${VENV_DIR}/bin/python" -m pip install --upgrade --no-cache-dir pip setuptools wheel

    echo "Instalando librerías analíticas y geoespaciales..."
    "${VENV_DIR}/bin/python" -m pip install --no-cache-dir \
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
        openpyxl==3.1.5 \
        findspark==2.0.1 \
        ipykernel==6.29.5

    # Si es el Master y tenemos el bucket, empaquetar y subir la caché para los siguientes clústeres
    if [[ "$IS_MASTER" = true && -n "$CACHE_URI" ]]; then
        echo "Empaquetando venv y subiendo a S3 (${CACHE_URI}) para que futuros clústeres arranquen en segundos..."
        tar -czf /tmp/venv.tar.gz -C "${INSTALL_DIR}" venv
        aws s3 cp /tmp/venv.tar.gz "${CACHE_URI}" || echo "Aviso: No se pudo subir la caché a S3."
        rm -f /tmp/venv.tar.gz
        echo "Caché subida a S3 con éxito."
    fi
fi

# 3. Asegurar permisos totales para el usuario hadoop
sudo chown -R hadoop:hadoop "${INSTALL_DIR}"

# 4. Configurar variables de entorno globales para todas las sesiones bash
cat << 'EOF' | sudo tee /etc/profile.d/american_tower_env.sh > /dev/null
export PATH="/opt/american-tower/venv/bin:$PATH"
export PYSPARK_PYTHON="/opt/american-tower/venv/bin/python"
export PYSPARK_DRIVER_PYTHON="/opt/american-tower/venv/bin/python"
EOF
sudo chmod +x /etc/profile.d/american_tower_env.sh

# 5. Registrar kernel de Jupyter si es el Master
if [[ "$IS_MASTER" = true ]]; then
    echo "Nodo Master: Registrando kernel de Jupyter para usuario hadoop..."
    "${VENV_DIR}/bin/python" -m ipykernel install \
        --name american-tower \
        --display-name "American Tower - PySpark" || true
    sudo -u hadoop "${VENV_DIR}/bin/python" -m ipykernel install \
        --user --name american-tower \
        --display-name "American Tower - PySpark" || true
fi

echo "Bootstrap finalizado con éxito en $(hostname) a las $(date -u)"
