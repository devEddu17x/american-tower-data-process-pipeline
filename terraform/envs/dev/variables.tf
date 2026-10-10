variable "aws_region" {
  description = "AWS region where bootstrap resources are provisioned"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS shared config profile name"
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project identifier used in naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment identifier for bootstrap resources"
  type        = string
}

variable "my_ip" {
  description = "Your current IP address or CIDR block allowed for SSH access (e.g. 181.67.24.172 or 0.0.0.0/0)"
  type        = string
}

variable "key_pair_name" {
  description = "Optional existing EC2 Key Pair name (leave null to auto-generate a new key pair)"
  type        = string
  default     = null
}

variable "master_instance_type" {
  description = "EC2 instance type for EMR Master node"
  type        = string
  default     = "m5.xlarge"
}

variable "core_instance_type" {
  description = "EC2 instance type for EMR Core nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "core_instance_count" {
  description = "Number of Core worker instances provisioned when enable_emr is true. Any non-negative integer; 0 keeps a single master node."
  type        = number
  default     = 3

  validation {
    condition     = var.core_instance_count >= 0 && floor(var.core_instance_count) == var.core_instance_count
    error_message = "core_instance_count must be a non-negative integer."
  }
}

variable "idle_timeout" {
  description = "Idle timeout in seconds before cluster auto-termination"
  type        = number
  default     = 3600
}

variable "enable_emr" {
  description = "Flag to control whether the EMR cluster is provisioned (set false to terminate cluster and preserve S3 data)"
  type        = bool
  default     = true
}

