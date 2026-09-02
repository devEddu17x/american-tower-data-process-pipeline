variable "instance_profile_arn" {
  description = "ARN of the IAM instance profile for EMR EC2"
  type        = string
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile for EMR EC2"
  type        = string
}

variable "service_role_arn" {
  description = "ARN of the IAM service role for EMR"
  type        = string
}

variable "service_role_name" {
  description = "Name of the IAM service role for EMR"
  type        = string
}

variable "iam_dependency_ids" {
  description = "List of dependency resource IDs to trigger sleep upon changes"
  type        = list(string)
  default     = []
}

variable "propagation_wait_seconds" {
  description = "Seconds to wait for IAM propagation across AWS endpoints"
  type        = number
  default     = 15
}
