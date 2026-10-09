variable "project_name" {
  description = "Project identifier used in naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "bucket_name" {
  description = "Explicit S3 bucket name. If null, a name will be generated using bucket_prefix"
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Whether to allow bucket deletion even if it contains objects (false prevents accidental deletion)"
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "create_prefix_markers" {
  description = "Whether to create placeholder objects for top-level Data Lake prefixes"
  type        = bool
  default     = true
}

variable "initial_prefixes" {
  description = "List of folder prefixes to create as folder markers in the bucket"
  type        = list(string)
  default = [
    "bronze/",
    "silver/",
    "gold/",
    "quarantine/",
    "artifacts/config/",
    "artifacts/models/",
    "evidence/",
    "benchmarks/",
    "logs/",
  ]
}

variable "tags" {
  description = "Additional tags to merge with default tags"
  type        = map(string)
  default     = {}
}

