output "glue_database_name" {
  description = "AWS Glue Data Catalog database name for Gold tables"
  value       = aws_glue_catalog_database.gold.name
}

output "glue_crawler_name" {
  description = "On-demand AWS Glue Crawler name for Gold bucket discovery"
  value       = aws_glue_crawler.gold.name
}

output "glue_crawler_role_arn" {
  description = "IAM Role ARN used by the Glue Crawler"
  value       = aws_iam_role.glue_crawler_role.arn
}

output "athena_workgroup_name" {
  description = "Amazon Athena Workgroup name for analytical queries and QuickSight"
  value       = aws_athena_workgroup.this.name
}

output "athena_output_location" {
  description = "S3 URI where Athena query results are stored"
  value       = local.athena_output_location
}

output "gold_table_names" {
  description = "Managed Glue Catalog table names pointing to Gold Parquet datasets"
  value = {
    panel_distrital      = aws_glue_catalog_table.panel_distrital.name
    contexto_territorial = aws_glue_catalog_table.contexto_territorial.name
    predicciones_modelos = aws_glue_catalog_table.predicciones_modelos.name
  }
}

output "predicciones_s3_uri" {
  description = "Fixed S3 Gold prefix where the 4 models write Parquet inference outputs"
  value       = "s3://${var.gold_bucket_id}/predicciones_modelos/"
}

output "athena_named_query_ids" {
  description = "Saved Athena Named Query IDs ready to execute in console or CLI"
  value = {
    create_vw_panel_enriquecido = aws_athena_named_query.create_vw_panel_enriquecido.id
    kpi_resumen_trimestral      = aws_athena_named_query.kpi_resumen_trimestral.id
    kpi_punto_ciego_y_brecha    = aws_athena_named_query.kpi_punto_ciego_y_brecha.id
  }
}

output "quicksight_data_source_arn" {
  description = "QuickSight Athena Data Source ARN"
  value       = var.enable_quicksight ? aws_quicksight_data_source.athena_gold[0].arn : null
}

output "quicksight_data_set_arn" {
  description = "QuickSight SPICE Dataset ARN (Panel Distrital Enriquecido)"
  value       = var.enable_quicksight ? aws_quicksight_data_set.panel_enriquecido[0].arn : null
}

output "quicksight_data_set_id" {
  description = "QuickSight SPICE Dataset ID (Panel Distrital Enriquecido)"
  value       = var.enable_quicksight ? aws_quicksight_data_set.panel_enriquecido[0].data_set_id : ""
}

output "quicksight_inferencias_data_set_arn" {
  description = "QuickSight DIRECT_QUERY Dataset ARN (Inferencias de Modelos)"
  value       = var.enable_quicksight ? aws_quicksight_data_set.inferencias_modelos[0].arn : null
}
