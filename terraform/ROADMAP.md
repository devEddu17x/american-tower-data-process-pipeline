# Plan de Infraestructura de Consumo e Inferencia (Terraform)

Hoja de ruta corta para completar la arquitectura sobre AWS (`us-east-1`, sin romper los módulos existentes ni el interruptor `enable_emr`). El `terraform apply` siempre lo ejecuta el usuario.

## Paso 1 — Módulo `terraform/modules/catalog` (Glue + Athena → QuickSight)
- **AWS Glue Data Catalog:** Base de datos `american_tower_dev_gold` + Glue Crawler (y/o tablas externas) apuntando a `panel_distrital/` y `contexto_territorial/` en S3 Gold (`run_id` configurable por variable).
- **Amazon Athena:** Workgroup dedicado con salida en `s3://<operations>/athena-results/` y límite de bytes escaneados por consulta.
- **Vista SQL para BI:** `vw_panel_enriquecido` uniendo `panel_distrital` + `contexto_territorial` para conectar directamente a **Amazon QuickSight** (usando los 30 días gratis).

## Paso 2 — Módulo `terraform/modules/lambda` (Automatización Bronze → Gold)
- **Trigger S3:** Evento `s3:ObjectCreated:*` sobre el prefijo `incoming/ookla/` en S3 Bronze (para probar con los trimestres reales nuevos `2026-T2` y `2026-T3`).
- **AWS Lambda:** Envía un EMR Step (`spark-submit`) al clúster activo para ejecutar Bronze → Silver → Gold y dispara el Glue Crawler al terminar para actualizar Athena y QuickSight.

## Paso 3 — Módulo `terraform/modules/sagemaker` (Inferencia Serverless en CPU)
- **Base persistente:** Repositorio **Amazon ECR** (imagen CPU de inferencia) + **IAM Role** de SageMaker con lectura sobre `s3://<artifacts>/models/` y `s3://<gold>/`.
- **Endpoint desacoplado:** Recursos de **SageMaker Serverless Inference** (solo CPU, \$0 en reposo) protegidos con un toggle `enable_sagemaker = false` hasta que los 4 integrantes publiquen sus modelos entrenados.
