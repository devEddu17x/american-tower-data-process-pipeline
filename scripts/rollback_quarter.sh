#!/usr/bin/env bash
# ==============================================================================
# Rollback de un trimestre incremental (ej. 2026Q2 o 2026Q3) para repetir demos
# ==============================================================================
# Uso:
#   ./scripts/rollback_quarter.sh 2026Q2
#   ./scripts/rollback_quarter.sh 2026Q3
# ==============================================================================

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <YYYYQ#>  (ejemplo: $0 2026Q2)" >&2
  exit 1
fi

QUARTER_TAG="$1"
if [[ ! "$QUARTER_TAG" =~ ^([0-9]{4})Q([1-4])$ ]]; then
  echo "Formato invalido: '$QUARTER_TAG'. Usa YYYYQ# (ej. 2026Q2)." >&2
  exit 1
fi

YEAR="${BASH_REMATCH[1]}"
QUARTER="${BASH_REMATCH[2]}"
MONTH=$(printf "%02d" $(( (QUARTER - 1) * 3 + 1 )))
PERIOD_ID=$(( YEAR * 4 + (QUARTER - 1) ))

AWS_PROFILE="${AWS_PROFILE:-bigdata}"
AWS_REGION="${AWS_REGION:-us-east-1}"
GOLD_RUN_ID="${GOLD_RUN_ID:-20261125T073334Z-7ea4f607ff}"

echo "Obteniendo salidas de Terraform..."
BRONZE_BUCKET=$(terraform -chdir=terraform/envs/dev output -raw bronze_bucket_id)
SILVER_BUCKET=$(terraform -chdir=terraform/envs/dev output -raw silver_bucket_id)
GOLD_BUCKET=$(terraform -chdir=terraform/envs/dev output -raw gold_bucket_id)
OPERATIONS_BUCKET=$(terraform -chdir=terraform/envs/dev output -raw operations_bucket_id)
QS_DATASET_ARN=$(terraform -chdir=terraform/envs/dev output -raw quicksight_data_set_arn 2>/dev/null || true)

GOLD_URI="s3://${GOLD_BUCKET}/run_id=${GOLD_RUN_ID}/panel_distrital/year=${YEAR}/incremental_${QUARTER_TAG}.parquet"
BRONZE_URI="s3://${BRONZE_BUCKET}/incoming/ookla/${YEAR}-${MONTH}-01_performance_mobile_tiles.parquet"
SILVER_PREFIX="s3://${SILVER_BUCKET}/incremental/ookla_teselas/period_id=${PERIOD_ID}/"
OPS_PREFIX="s3://${OPERATIONS_BUCKET}/incremental/ookla/${QUARTER_TAG}/"

echo "Eliminando artefactos incrementales de ${QUARTER_TAG} (period_id=${PERIOD_ID}):"
echo "  - Gold:       ${GOLD_URI}"
aws s3 rm "${GOLD_URI}" --profile "$AWS_PROFILE" --region "$AWS_REGION" || true

echo "  - Bronze:     ${BRONZE_URI}"
aws s3 rm "${BRONZE_URI}" --profile "$AWS_PROFILE" --region "$AWS_REGION" || true

echo "  - Silver:     ${SILVER_PREFIX}"
aws s3 rm "${SILVER_PREFIX}" --recursive --profile "$AWS_PROFILE" --region "$AWS_REGION" || true

echo "  - Operations: ${OPS_PREFIX}"
aws s3 rm "${OPS_PREFIX}" --recursive --profile "$AWS_PROFILE" --region "$AWS_REGION" || true

if [[ -n "$QS_DATASET_ARN" && "$QS_DATASET_ARN" != "null" ]]; then
  ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
  DATASET_ID="${QS_DATASET_ARN##*/}"
  INGESTION_ID="rollback-${QUARTER_TAG}-$(date -u +%Y%m%dT%H%M%SZ)"
  echo "Refrescando SPICE en QuickSight (${DATASET_ID})..."
  aws quicksight create-ingestion \
    --aws-account-id "$ACCOUNT_ID" \
    --data-set-id "$DATASET_ID" \
    --ingestion-id "$INGESTION_ID" \
    --ingestion-type FULL_REFRESH \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query "[IngestionId,IngestionStatus]" \
    --output text
fi

echo "Rollback de ${QUARTER_TAG} completado."
