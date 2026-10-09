output "bucket_id" {
  description = "The name/ID of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "prefix_map" {
  description = "Map of S3 URI prefixes conforming to the Data Lake convention"
  value = {
    bronze     = "s3://${aws_s3_bucket.this.id}/bronze/"
    silver     = "s3://${aws_s3_bucket.this.id}/silver/"
    gold       = "s3://${aws_s3_bucket.this.id}/gold/"
    quarantine = "s3://${aws_s3_bucket.this.id}/quarantine/"
    artifacts  = "s3://${aws_s3_bucket.this.id}/artifacts/"
    evidence   = "s3://${aws_s3_bucket.this.id}/evidence/"
    benchmarks = "s3://${aws_s3_bucket.this.id}/benchmarks/"
    logs       = "s3://${aws_s3_bucket.this.id}/logs/"
  }
}
