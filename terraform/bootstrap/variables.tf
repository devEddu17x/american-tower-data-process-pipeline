variable "aws_region" {
  description = "AWS region where bootstrap resources are provisioned"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS shared config profile name"
  type        = string
  default     = "bigdata"
}

variable "project_name" {
  description = "Project identifier used in naming resources"
  type        = string
  default     = "american-tower"
}

variable "environment" {
  description = "Environment identifier for bootstrap resources"
  type        = string
  default     = "dev"
}
