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
  value       = module.emr.cluster_id
}

output "emr_master_public_dns" {
  description = "Public DNS of the EMR Master node"
  value       = module.emr.master_public_dns
}

output "emr_private_key_path" {
  description = "Path to the auto-generated private key (.pem) file"
  value       = abspath(local_sensitive_file.emr_private_key.filename)
}

output "emr_ssh_connection_string" {
  description = "SSH connection command to connect to the Master node"
  value       = "ssh -i ${abspath(local_sensitive_file.emr_private_key.filename)} hadoop@${module.emr.master_public_dns}"
}

output "emr_artifacts_bucket" {
  description = "S3 bucket for EMR scripts and artifacts"
  value       = aws_s3_bucket.emr_artifacts.id
}

output "datalake_bucket_id" {
  description = "ID/Name of the Central Data Lake S3 Bucket"
  value       = module.s3_datalake.bucket_id
}

output "datalake_bucket_arn" {
  description = "ARN of the Central Data Lake S3 Bucket"
  value       = module.s3_datalake.bucket_arn
}

output "datalake_prefix_map" {
  description = "Map of Data Lake S3 URIs organized by convention"
  value       = module.s3_datalake.prefix_map
}

