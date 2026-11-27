output "ecr_repository_url" {
  description = "Amazon ECR repository URL for the CPU inference Docker image"
  value       = aws_ecr_repository.inference.repository_url
}

output "ecr_repository_arn" {
  description = "Amazon ECR repository ARN"
  value       = aws_ecr_repository.inference.arn
}

output "sagemaker_execution_role_arn" {
  description = "IAM Execution Role ARN for SageMaker Serverless Inference"
  value       = aws_iam_role.sagemaker_execution.arn
}

output "sagemaker_endpoint_name" {
  description = "Active SageMaker Serverless Endpoint name (null when enable_sagemaker = false)"
  value       = var.enable_sagemaker ? aws_sagemaker_endpoint.this[0].name : null
}

output "sagemaker_endpoint_arn" {
  description = "Active SageMaker Serverless Endpoint ARN (null when enable_sagemaker = false)"
  value       = var.enable_sagemaker ? aws_sagemaker_endpoint.this[0].arn : null
}
