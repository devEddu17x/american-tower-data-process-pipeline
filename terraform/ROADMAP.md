# Plan de Infraestructura de Consumo e Inferencia (Terraform)

Hoja de ruta de la infraestructura de consumo, automatización e inferencia sobre AWS (`us-east-1`, sin romper los módulos existentes ni el interruptor `enable_emr`). El `terraform apply` siempre lo ejecuta el usuario.

## Paso 1 — Módulo `terraform/modules/catalog` (Glue + Athena + QuickSight) — COMPLETADO Y DESPLEGADO
- [x] **AWS Glue Data Catalog:** Base de datos `american_tower_dev_gold`, tablas externas `panel_distrital` (con Athena Partition Projection `2019..2030`), `contexto_territorial` y `predicciones_modelos` (`s3://<gold>/predicciones_modelos/`), más Glue Crawler bajo demanda.
- [x] **Amazon Athena:** Workgroup `american-tower-dev-workgroup` (Engine v3) con salida cifrada en `s3://<operations>/athena-results/`, tope de 1 GB por consulta y 3 Named Queries guardadas.
- [x] **Amazon QuickSight:** Permisos IAM en `aws-quicksight-service-role-v0`, Data Source Athena, Dataset SPICE `Panel Distrital Enriquecido (dev)` (54,810 filas) y Dataset `DIRECT_QUERY` `Inferencias de Modelos (dev)` con pestaña comparativa para los 4 modelos.

## Paso 2 — Módulo `terraform/modules/lambda` (Automatización Bronze → Gold) — COMPLETADO Y DESPLEGADO
- [x] **Trigger S3 → Lambda → EMR Step:** Evento `s3:ObjectCreated:*` sobre `incoming/ookla/*.parquet` → Lambda (`terraform/services/lambda/bronze-to-emr-trigger/trigger_emr.py`) → EMR Step con `terraform/services/emr/process_incremental_ookla.py` → archivo atómico en Gold + refresh SPICE en QuickSight.
- [x] **Rollback para demos:** `scripts/rollback_quarter.sh <YYYYQ#>` elimina limpiamente un trimestre incremental (`2026Q2` / `2026Q3`) y refresca SPICE.

## Paso 3 — Módulo `terraform/modules/sagemaker` (Inferencia Serverless CPU Spark MLlib) — COMPLETADO (LISTO PARA ACTIVAR)
- [x] **Base persistente:** Repositorio **Amazon ECR** (`american-tower-dev-inference`, retención de 3 imágenes) + **IAM Execution Role** con lectura sobre `artifacts/models/*` y `gold/*`, y escritura en `gold/predicciones_modelos/*`.
- [x] **Contenedor Spark MLlib:** `terraform/services/sagemaker/inference/` (`Dockerfile` con OpenJDK 17 + PySpark 3.5.0, `serve.py` cargando `PipelineModel` multi-modelo en CPU, 3072 MB RAM por defecto).
- [x] **Endpoint protegido:** `enable_sagemaker = false` hasta subir la imagen Docker a ECR y los 4 modelos de Spark MLlib en `s3://<artifacts>/models/<modelo>/`.
- [ ] **Pendiente para activar endpoint:** Integrar los modelos de los otros 3 integrantes, hacer build/push de la imagen a ECR y aplicar `terraform apply -var="enable_sagemaker=true"`.
