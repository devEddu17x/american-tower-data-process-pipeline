variable "project_name" {
  description = "Project identifier used in naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for EMR cluster placement"
  type        = string
}

variable "emr_master_sg_id" {
  description = "Security group ID for EMR Master node"
  type        = string
}

variable "emr_slave_sg_id" {
  description = "Security group ID for EMR Slave (Core/Task) nodes"
  type        = string
}

variable "emr_service_access_sg_id" {
  description = "Security group ID for EMR Service Access (only for private subnets, null for public)"
  type        = string
  default     = null
}

variable "service_role_arn" {
  description = "ARN of the IAM role assumed by the EMR service"
  type        = string
}

variable "instance_profile_arn" {
  description = "ARN or name of the IAM instance profile for EMR EC2 instances"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access to the Master node"
  type        = string
}

variable "bootstrap_s3_path" {
  description = "S3 URI to the bootstrap script (e.g. s3://my-bucket/bootstrap.sh)"
  type        = string
  default     = null
}

variable "release_label" {
  description = "EMR release version label"
  type        = string
  default     = "emr-7.1.0"
}

variable "master_instance_type" {
  description = "EC2 instance type for the Master node"
  type        = string
  default     = "m5.xlarge"
}

variable "core_instance_type" {
  description = "EC2 instance type for Core nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "core_instance_count" {
  description = "Number of Core instances to provision (0 for single-node development)"
  type        = number
  default     = 2
}

variable "idle_timeout" {
  description = "Idle timeout in seconds before auto-termination kicks in"
  type        = number
  default     = 3600
}

variable "log_uri" {
  description = "S3 URI for EMR cluster logs (e.g. s3://my-bucket/logs/)"
  type        = string
  default     = null
}

