resource "aws_sagemaker_model" "this" {
  count              = var.enable_sagemaker ? 1 : 0
  name               = "${var.project_name}-${var.environment}-models"
  execution_role_arn = aws_iam_role.sagemaker_execution.arn

  primary_container {
    image          = "${aws_ecr_repository.inference.repository_url}:${var.inference_image_tag}"
    model_data_url = var.model_data_url

    environment = {
      AWS_DEFAULT_REGION  = var.aws_region
      ARTIFACTS_BUCKET    = var.artifacts_bucket_id
      S3_MODELS_PREFIX    = "s3://${var.artifacts_bucket_id}/models/"
      GOLD_BUCKET         = var.gold_bucket_id
      GOLD_RUN_ID         = var.gold_run_id
      PREDICCIONES_PREFIX = "predicciones_modelos/"
    }
  }

  depends_on = [aws_iam_role_policy.sagemaker_permissions]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sagemaker_endpoint_configuration" "serverless" {
  count = var.enable_sagemaker ? 1 : 0
  name  = "${var.project_name}-${var.environment}-serverless-config"

  production_variants {
    variant_name = "AllModelsCPU"
    model_name   = aws_sagemaker_model.this[0].name

    serverless_config {
      memory_size_in_mb = var.serverless_memory_mb
      max_concurrency   = var.serverless_max_concurrency
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sagemaker_endpoint" "this" {
  count                = var.enable_sagemaker ? 1 : 0
  name                 = "${var.project_name}-${var.environment}-serverless-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.serverless[0].name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
