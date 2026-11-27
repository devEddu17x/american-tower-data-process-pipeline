output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = module.networking.public_subnet_id
}

output "emr_master_sg_id" {
  description = "Security Group ID of EMR Master"
  value       = module.networking.emr_master_sg_id
}

output "emr_slave_sg_id" {
  description = "Security Group ID of EMR Slaves"
  value       = module.networking.emr_slave_sg_id
}

output "emr_service_access_sg_id" {
  description = "Security Group ID of EMR Service Access"
  value       = module.networking.emr_service_access_sg_id
}

output "emr_cluster_id" {
  description = "EMR Cluster ID"
  value       = var.enable_emr ? module.emr[0].cluster_id : null
}

output "emr_master_public_dns" {
  description = "Public DNS of the EMR Master node"
  value       = var.enable_emr ? module.emr[0].master_public_dns : null
}

output "emr_private_key_path" {
  description = "Path to the auto-generated private key (.pem) file"
  value       = abspath(local_sensitive_file.emr_private_key.filename)
}

output "emr_ssh_connection_string" {
  description = "SSH connection command to connect to the Master node"
  value       = var.enable_emr ? "ssh -i ${abspath(local_sensitive_file.emr_private_key.filename)} hadoop@${module.emr[0].master_public_dns}" : null
}

output "emr_ssm_key_parameter" {
  description = "SSM Parameter Store path containing the private SSH key"
  value       = aws_ssm_parameter.emr_ssh_private_key.name
}

output "bronze_bucket_id" {
  description = "ID/Name of the Bronze S3 Bucket"
  value       = module.s3_datalake.bronze_bucket_id
}

output "silver_bucket_id" {
  description = "ID/Name of the Silver S3 Bucket"
  value       = module.s3_datalake.silver_bucket_id
}

output "gold_bucket_id" {
  description = "ID/Name of the Gold S3 Bucket"
  value       = module.s3_datalake.gold_bucket_id
}

output "operations_bucket_id" {
  description = "ID/Name of the Operations S3 Bucket"
  value       = module.s3_datalake.operations_bucket_id
}

output "artifacts_bucket_id" {
  description = "ID/Name of the Artifacts S3 Bucket"
  value       = module.s3_datalake.artifacts_bucket_id
}

output "datalake_bucket_ids" {
  description = "Map of all 5 S3 Bucket IDs"
  value       = module.s3_datalake.bucket_ids
}

output "datalake_uri_map" {
  description = "Map of S3 URIs for all data layers and operational prefixes"
  value       = module.s3_datalake.uri_map
}

output "glue_database_name" {
  description = "AWS Glue Data Catalog database name for Gold tables"
  value       = module.catalog.glue_database_name
}

output "glue_crawler_name" {
  description = "On-demand AWS Glue Crawler name for Gold bucket discovery"
  value       = module.catalog.glue_crawler_name
}

output "athena_workgroup_name" {
  description = "Amazon Athena Workgroup name for analytical queries and QuickSight"
  value       = module.catalog.athena_workgroup_name
}

output "athena_output_location" {
  description = "S3 URI where Athena query results are stored"
  value       = module.catalog.athena_output_location
}

output "gold_table_names" {
  description = "Managed Glue Catalog table names pointing to Gold Parquet datasets"
  value       = module.catalog.gold_table_names
}

output "athena_named_query_ids" {
  description = "Saved Athena Named Query IDs ready to execute in console or CLI"
  value       = module.catalog.athena_named_query_ids
}

output "quicksight_data_source_arn" {
  description = "QuickSight Athena Data Source ARN"
  value       = module.catalog.quicksight_data_source_arn
}

output "quicksight_data_set_arn" {
  description = "QuickSight SPICE Dataset ARN (Panel Distrital Enriquecido)"
  value       = module.catalog.quicksight_data_set_arn
}

output "quicksight_inferencias_data_set_arn" {
  description = "QuickSight DIRECT_QUERY Dataset ARN (Inferencias de Modelos)"
  value       = module.catalog.quicksight_inferencias_data_set_arn
}

output "predicciones_s3_uri" {
  description = "Fixed S3 Gold prefix where the 4 models write Parquet inference outputs"
  value       = module.catalog.predicciones_s3_uri
}

output "bronze_trigger_lambda_name" {
  description = "Name of the Bronze-to-EMR incremental trigger Lambda function"
  value       = module.bronze_trigger.lambda_function_name
}

output "bronze_incoming_s3_uri" {
  description = "Bronze S3 prefix monitored for new Ookla Parquet uploads (e.g. 2026-T2 / 2026-T3)"
  value       = module.bronze_trigger.incoming_s3_uri
}

output "sagemaker_ecr_repository_url" {
  description = "Amazon ECR repository URL for the CPU inference Docker image"
  value       = module.sagemaker.ecr_repository_url
}

output "sagemaker_execution_role_arn" {
  description = "IAM Execution Role ARN for SageMaker Serverless Inference"
  value       = module.sagemaker.sagemaker_execution_role_arn
}

output "sagemaker_endpoint_name" {
  description = "Active SageMaker Serverless Endpoint name (null when enable_sagemaker = false)"
  value       = module.sagemaker.sagemaker_endpoint_name
}



