variable "project_name" {
  description = "Project identifier used in naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment identifier (e.g. dev)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for runtime environment variables"
  type        = string
  default     = "us-east-1"
}

variable "artifacts_bucket_id" {
  description = "S3 bucket ID for model artifacts (artifacts/models/)"
  type        = string
}

variable "artifacts_bucket_arn" {
  description = "S3 bucket ARN for model artifacts"
  type        = string
}

variable "gold_bucket_id" {
  description = "S3 bucket ID for Gold layer (contexto_territorial & predicciones_modelos)"
  type        = string
}

variable "gold_bucket_arn" {
  description = "S3 bucket ARN for Gold layer"
  type        = string
}

variable "gold_run_id" {
  description = "Active Gold run_id prefix for territorial context lookup"
  type        = string
}

variable "enable_sagemaker" {
  description = "Toggle to provision the SageMaker Serverless Model, Endpoint Config, and Endpoint (keep false until image is pushed to ECR)"
  type        = bool
  default     = false
}

variable "inference_image_tag" {
  description = "Docker image tag in the ECR inference repository"
  type        = string
  default     = "latest"
}

variable "model_data_url" {
  description = "Optional S3 URI to a model.tar.gz bundle (null if container loads the 4 models dynamically from S3_MODELS_PREFIX)"
  type        = string
  default     = null
}

variable "serverless_memory_mb" {
  description = "CPU Serverless Inference memory in MB (1024, 2048, 3072, 4096, 5120, or 6144)"
  type        = number
  default     = 3072

  validation {
    condition     = contains([1024, 2048, 3072, 4096, 5120, 6144], var.serverless_memory_mb)
    error_message = "serverless_memory_mb must be one of 1024, 2048, 3072, 4096, 5120, or 6144."
  }
}

variable "serverless_max_concurrency" {
  description = "Maximum concurrent invocations for SageMaker Serverless Inference (1 to 200)"
  type        = number
  default     = 5

  validation {
    condition     = var.serverless_max_concurrency >= 1 && var.serverless_max_concurrency <= 200
    error_message = "serverless_max_concurrency must be between 1 and 200."
  }
}
