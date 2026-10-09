module "networking" {
  source = "../../modules/networking"
  my_ip  = var.my_ip
}

module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

module "iam_to_emr_integration" {
  source                   = "../../modules/integrations/iam_to_emr"
  instance_profile_arn     = module.iam.emr_ec2_instance_profile_arn
  instance_profile_name    = module.iam.emr_ec2_instance_profile_name
  service_role_arn         = module.iam.emr_service_role_arn
  service_role_name        = module.iam.emr_service_role_name
  iam_dependency_ids       = module.iam.iam_dependency_ids
  propagation_wait_seconds = 15
}

# Central Data Lake S3 Bucket (Protected from accidental deletion)
module "s3_datalake" {
  source        = "../../modules/s3"
  project_name  = var.project_name
  environment   = var.environment
  force_destroy = false
}

# Ephemeral SSH Key Pair Generation
resource "tls_private_key" "emr_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "emr_key_pair" {
  count      = var.key_pair_name == null ? 1 : 0
  key_name   = "${var.project_name}-${var.environment}-emr-key"
  public_key = tls_private_key.emr_ssh_key.public_key_openssh

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "local_sensitive_file" "emr_private_key" {
  content         = tls_private_key.emr_ssh_key.private_key_pem
  filename        = "${path.module}/.ssh/${var.project_name}-${var.environment}-key.pem"
  file_permission = "0400"
}

# Securely publish the private key to SSM Parameter Store so all team members can fetch it
resource "aws_ssm_parameter" "emr_ssh_private_key" {
  name        = "/${var.project_name}/${var.environment}/emr_ssh_key"
  description = "Private SSH key for EMR Master node access"
  type        = "SecureString"
  value       = tls_private_key.emr_ssh_key.private_key_pem

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Bootstrap script upload to artifacts bucket
resource "aws_s3_object" "bootstrap_script" {
  bucket = module.s3_datalake.artifacts_bucket_id
  key    = "scripts/bootstrap.sh"
  source = "${path.module}/../../../scripts/bootstrap.sh"
  etag   = filemd5("${path.module}/../../../scripts/bootstrap.sh")
}

# EMR Cluster Engine
locals {
  selected_key_name = var.key_pair_name != null ? var.key_pair_name : aws_key_pair.emr_key_pair[0].key_name
}

module "emr" {
  count                = var.enable_emr ? 1 : 0
  source               = "../../modules/emr"
  project_name         = var.project_name
  environment          = var.environment
  public_subnet_id     = module.networking.public_subnet_id
  emr_master_sg_id     = module.networking.emr_master_sg_id
  emr_slave_sg_id      = module.networking.emr_slave_sg_id
  service_role_arn     = module.iam_to_emr_integration.service_role_arn
  instance_profile_arn = module.iam_to_emr_integration.instance_profile_arn
  key_pair_name        = local.selected_key_name
  bootstrap_s3_path    = "s3://${module.s3_datalake.artifacts_bucket_id}/${aws_s3_object.bootstrap_script.key}"
  log_uri              = "s3://${module.s3_datalake.artifacts_bucket_id}/logs/"
  master_instance_type = var.master_instance_type
  core_instance_type   = var.core_instance_type
  core_instance_count  = var.core_instance_count
  idle_timeout         = var.idle_timeout

  depends_on = [
    aws_s3_object.bootstrap_script
  ]
}

# VS Code Remote-SSH Config Generation
resource "local_file" "emr_ssh_config" {
  count   = var.enable_emr ? 1 : 0
  content = <<-EOT
    Host emr-studio
        HostName ${module.emr[0].master_public_dns}
        User hadoop
        IdentityFile ${abspath(local_sensitive_file.emr_private_key.filename)}
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        LogLevel ERROR
  EOT

  filename = "${path.module}/.ssh/config"
}


