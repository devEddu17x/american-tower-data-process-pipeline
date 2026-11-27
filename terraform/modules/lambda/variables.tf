variable "project_name" {
  description = "Project identifier used in naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment identifier (e.g. dev)"
  type        = string
}

variable "bronze_bucket_id" {
  description = "S3 bucket ID for the Bronze layer"
  type        = string
}

variable "bronze_bucket_arn" {
  description = "S3 bucket ARN for the Bronze layer"
  type        = string
}

variable "silver_bucket_id" {
  description = "S3 bucket ID for the Silver layer"
  type        = string
}

variable "gold_bucket_id" {
  description = "S3 bucket ID for the Gold layer"
  type        = string
}

variable "operations_bucket_id" {
  description = "S3 bucket ID for the Operations layer"
  type        = string
}

variable "incremental_script_s3_uri" {
  description = "S3 URI of scripts/process_incremental_ookla.py in the artifacts bucket"
  type        = string
}

variable "bronze_manifest_uri" {
  description = "S3 URI of the active Bronze _SUCCESS.json manifest (for INEI Distrito.rar)"
  type        = string
}

variable "silver_manifest_uri" {
  description = "S3 URI of the active Silver _SUCCESS.json manifest (for distritos table)"
  type        = string
}

variable "gold_run_id" {
  description = "Active Gold run_id prefix where incremental quarter Parquet files are written"
  type        = string
}

variable "quicksight_dataset_id" {
  description = "QuickSight SPICE dataset ID to refresh after Gold update (empty to skip)"
  type        = string
  default     = ""
}

variable "incoming_prefix" {
  description = "Bronze S3 prefix monitored for new Ookla Parquet uploads"
  type        = string
  default     = "incoming/ookla/"
}

variable "source_file_path" {
  description = "Local filesystem path to the Python Lambda handler file"
  type        = string
}
