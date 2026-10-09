variable "project_name" {
  description = "Project identifier used in naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "force_destroy" {
  description = "Whether to allow bucket deletion even if it contains objects (false protects data)"
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable versioning for all S3 buckets"
  type        = bool
  default     = true
}

variable "create_prefix_markers" {
  description = "Whether to create placeholder objects for top-level operational and artifact prefixes"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to merge with default tags"
  type        = map(string)
  default     = {}
}
