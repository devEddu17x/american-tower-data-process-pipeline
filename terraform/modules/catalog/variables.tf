variable "project_name" {
  description = "Project identifier used in naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment identifier (e.g. dev, prod)"
  type        = string
}

variable "gold_bucket_id" {
  description = "S3 bucket ID/name for the Gold layer"
  type        = string
}

variable "gold_bucket_arn" {
  description = "S3 bucket ARN for the Gold layer"
  type        = string
}

variable "operations_bucket_id" {
  description = "S3 bucket ID/name for the Operations layer (used for Athena query results)"
  type        = string
}

variable "operations_bucket_arn" {
  description = "S3 bucket ARN for the Operations layer (used to scope QuickSight Athena results permissions)"
  type        = string
}

variable "gold_run_id" {
  description = "Active Gold run_id prefix in S3 (e.g. 20261125T073334Z-7ea4f607ff)"
  type        = string
}

variable "athena_bytes_scanned_cutoff" {
  description = "Maximum bytes scanned per Athena query (cost guardrail, default 1 GB)"
  type        = number
  default     = 1073741824
}

variable "enable_quicksight" {
  description = "Provision QuickSight Athena Data Source, SPICE Dataset, and IAM permissions"
  type        = bool
  default     = true
}

variable "quicksight_namespace" {
  description = "QuickSight namespace (usually default)"
  type        = string
  default     = "default"
}

variable "quicksight_user_name" {
  description = "QuickSight user name granted ownership of Data Source and Dataset (defaults to AWS account ID)"
  type        = string
  default     = null
}

variable "quicksight_service_role_name" {
  description = "Existing QuickSight IAM service role name to attach S3/Athena/Glue read permissions"
  type        = string
  default     = "aws-quicksight-service-role-v0"
}

variable "quicksight_import_mode" {
  description = "QuickSight dataset import mode (SPICE or DIRECT_QUERY)"
  type        = string
  default     = "SPICE"

  validation {
    condition     = contains(["SPICE", "DIRECT_QUERY"], var.quicksight_import_mode)
    error_message = "quicksight_import_mode must be SPICE or DIRECT_QUERY."
  }
}
