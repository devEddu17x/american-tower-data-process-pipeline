output "lambda_function_name" {
  description = "Name of the Bronze-to-EMR trigger Lambda function"
  value       = aws_lambda_function.bronze_trigger.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Bronze-to-EMR trigger Lambda function"
  value       = aws_lambda_function.bronze_trigger.arn
}

output "incoming_s3_uri" {
  description = "Bronze S3 prefix monitored by the Lambda trigger"
  value       = "s3://${var.bronze_bucket_id}/${var.incoming_prefix}"
}
