resource "aws_emr_cluster" "cluster" {
  name          = "${var.project_name}-${var.environment}-cluster"
  release_label = var.release_label
  applications  = ["Hadoop", "Spark"]
  service_role  = var.service_role_arn
  log_uri       = var.log_uri

  ec2_attributes {
    subnet_id                         = var.public_subnet_id
    emr_managed_master_security_group = var.emr_master_sg_id
    emr_managed_slave_security_group  = var.emr_slave_sg_id
    service_access_security_group     = var.emr_service_access_sg_id
    instance_profile                  = var.instance_profile_arn
    key_name                          = var.key_pair_name
  }

  master_instance_group {
    instance_type  = var.master_instance_type
    instance_count = 1
  }

  dynamic "core_instance_group" {
    for_each = var.core_instance_count > 0 ? [1] : []
    content {
      instance_type  = var.core_instance_type
      instance_count = var.core_instance_count
    }
  }

  auto_termination_policy {
    idle_timeout = var.idle_timeout
  }

  dynamic "bootstrap_action" {
    for_each = var.bootstrap_s3_path != null && var.bootstrap_s3_path != "" ? [1] : []
    content {
      name = "Install Custom Dependencies"
      path = var.bootstrap_s3_path
    }
  }

  tags = {
    Name                                       = "${var.project_name}-${var.environment}-cluster"
    Project                                    = var.project_name
    Environment                                = var.environment
    ManagedBy                                  = "Terraform"
    "for-use-with-amazon-emr-managed-policies" = "true"
  }
}
