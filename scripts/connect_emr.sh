#!/usr/bin/env bash
# ==============================================================================
# Script de Conexión Automática a EMR Master Node (VS Code Remote & Terminal)
# ==============================================================================
# Este script automatiza completamente el flujo de conexión para cualquier
# miembro del equipo:
# 1. Obtiene dinámicamente el DNS público del nodo maestro de EMR en ejecución.
# 2. Descarga la llave SSH privada desde AWS SSM Parameter Store si no existe localmente.
# 3. Configura/actualiza automáticamente el bloque "Host emr-studio" en ~/.ssh/config.
# 4. Lanza VS Code conectado remotamente o una sesión SSH interactiva.
# ==============================================================================

set -euo pipefail

# Parámetros por defecto
AWS_PROFILE="${AWS_PROFILE:-bigdata}"
AWS_REGION="${AWS_REGION:-us-east-1}"
SSM_KEY_NAME="/american-tower/dev/emr_ssh_key"
LOCAL_KEY_PATH="${HOME}/.ssh/american-tower-dev-key.pem"
MODE="vscode"

# Colores para mensajes de consola
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

function usage() {
    echo -e "Uso: $0 [opciones]"
    echo -e ""
    echo -e "Opciones:"
    echo -e "  --terminal          Abre una sesión interactiva SSH en la terminal en lugar de VS Code"
    echo -e "  --vscode            Abre VS Code Remote-SSH en /home/hadoop (comportamiento por defecto)"
    echo -e "  --profile <perfil>  Perfil de AWS CLI (por defecto: bigdata)"
    echo -e "  --region <region>   Región de AWS (por defecto: us-east-1)"
    echo -e "  -h, --help          Muestra esta ayuda"
    exit 0
}

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        --terminal)
            MODE="terminal"
            shift
            ;;
        --vscode)
            MODE="vscode"
            shift
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}[ERROR] Opción desconocida: $1${NC}"
            usage
            ;;
    esac
done

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}    American Tower - Conexión Automática a EMR         ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "Perfil AWS : ${YELLOW}${AWS_PROFILE}${NC}"
echo -e "Región     : ${YELLOW}${AWS_REGION}${NC}"

# 1. Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}[ERROR] AWS CLI no está instalado en este sistema.${NC}"
    exit 1
fi

# 2. Localizar clúster EMR activo
echo -e "\n${CYAN}[1/4] Buscando clúster EMR activo...${NC}"
CLUSTER_ID=$(aws emr list-clusters \
    --cluster-states RUNNING WAITING \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query "Clusters[?starts_with(Name, 'american-tower')].Id | [0]" \
    --output text 2>/dev/null || true)

if [[ "$CLUSTER_ID" == "None" || -z "$CLUSTER_ID" ]]; then
    # Búsqueda fallback a cualquier clúster activo
    CLUSTER_ID=$(aws emr list-clusters \
        --cluster-states RUNNING WAITING \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query "Clusters[0].Id" \
        --output text 2>/dev/null || true)
fi

if [[ "$CLUSTER_ID" == "None" || -z "$CLUSTER_ID" ]]; then
    echo -e "${RED}[ERROR] No se encontró ningún clúster EMR en estado activo (RUNNING o WAITING).${NC}"
    echo -e "Verifica si el clúster está apagado o provisiona uno ejecutando:"
    echo -e "  terraform -chdir=terraform/envs/dev apply -var='enable_emr=true'"
    exit 1
fi

echo -e "Clúster ID encontrado: ${GREEN}${CLUSTER_ID}${NC}"

# Obtener DNS público del nodo maestro
MASTER_DNS=$(aws emr describe-cluster \
    --cluster-id "$CLUSTER_ID" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query "Cluster.MasterPublicDnsName" \
    --output text)

if [[ "$MASTER_DNS" == "None" || -z "$MASTER_DNS" ]]; then
    echo -e "${YELLOW}[AVISO] El clúster se está inicializando y aún no tiene DNS público asignado.${NC}"
    echo -e "Espera unos instantes y vuelve a ejecutar este script."
    exit 1
fi

echo -e "Master Public DNS     : ${GREEN}${MASTER_DNS}${NC}"

# 3. Asegurar la llave privada SSH
echo -e "\n${CYAN}[2/4] Verificando credenciales SSH...${NC}"
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

# Si ya existe una llave en el directorio local de terraform, usarla
DEV_LOCAL_KEY="$(dirname "$0")/../terraform/envs/dev/.ssh/american-tower-dev-key.pem"
if [[ ! -f "$LOCAL_KEY_PATH" && -f "$DEV_LOCAL_KEY" ]]; then
    cp "$DEV_LOCAL_KEY" "$LOCAL_KEY_PATH"
    chmod 400 "$LOCAL_KEY_PATH"
    echo -e "${GREEN}Llave sincronizada desde directorio local dev.${NC}"
fi

# Si aún no existe, descargarla desde AWS SSM Parameter Store
if [[ ! -f "$LOCAL_KEY_PATH" || ! -s "$LOCAL_KEY_PATH" ]]; then
    echo -e "Descargando llave privada desde AWS SSM (${SSM_KEY_NAME})..."
    aws ssm get-parameter \
        --name "$SSM_KEY_NAME" \
        --with-decryption \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query "Parameter.Value" \
        --output text > "$LOCAL_KEY_PATH"
    chmod 400 "$LOCAL_KEY_PATH"
    echo -e "${GREEN}Llave privada descargada y configurada en ${LOCAL_KEY_PATH}${NC}"
else
    chmod 400 "$LOCAL_KEY_PATH"
    echo -e "${GREEN}Llave privada disponible en ${LOCAL_KEY_PATH}${NC}"
fi

# 4. Actualizar ~/.ssh/config de forma idempotente
echo -e "\n${CYAN}[3/4] Actualizando configuración ~/.ssh/config...${NC}"
SSH_CONFIG="${HOME}/.ssh/config"
touch "$SSH_CONFIG"

# Crear bloque temporal
CONFIG_BLOCK="# BEGIN EMR-STUDIO AUTOMATION
Host emr-studio
    HostName ${MASTER_DNS}
    User hadoop
    IdentityFile ${LOCAL_KEY_PATH}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
# END EMR-STUDIO AUTOMATION"

# Si ya existe el bloque, reemplazarlo; si no, agregarlo al final
if grep -q "# BEGIN EMR-STUDIO AUTOMATION" "$SSH_CONFIG"; then
    python3 -c "
import sys, re
with open('$SSH_CONFIG', 'r') as f:
    content = f.read()
pattern = r'# BEGIN EMR-STUDIO AUTOMATION.*?# END EMR-STUDIO AUTOMATION'
new_block = '''$CONFIG_BLOCK'''
updated = re.sub(pattern, new_block, content, flags=re.DOTALL)
with open('$SSH_CONFIG', 'w') as f:
    f.write(updated)
"
else
    echo -e "\n${CONFIG_BLOCK}\n" >> "$SSH_CONFIG"
fi

echo -e "${GREEN}Configuración SSH actualizada exitosamente para 'Host emr-studio'.${NC}"

# 5. Iniciar conexión
echo -e "\n${CYAN}[4/4] Estableciendo conexión...${NC}"

if [[ "$MODE" == "vscode" ]]; then
    if command -v code &> /dev/null; then
        echo -e "${GREEN}Abriendo VS Code Remote-SSH en /home/hadoop...${NC}"
        code --remote ssh-remote+emr-studio /home/hadoop
        echo -e "${CYAN}¡Listo! VS Code se ha conectado al nodo maestro.${NC}"
        exit 0
    else
        echo -e "${YELLOW}[AVISO] Comando 'code' no encontrado en el PATH. Abriendo terminal SSH directa...${NC}"
        MODE="terminal"
    fi
fi

if [[ "$MODE" == "terminal" ]]; then
    echo -e "${GREEN}Iniciando sesión SSH interactiva:${NC}"
    echo -e "${YELLOW}ssh emr-studio${NC}\n"
    exec ssh emr-studio
fi

