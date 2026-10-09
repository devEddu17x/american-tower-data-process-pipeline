output "bucket_ids" {
  description = "Map of created S3 bucket IDs keyed by layer"
  value       = { for k, b in aws_s3_bucket.this : k => b.id }
}

output "bucket_arns" {
  description = "Map of created S3 bucket ARNs keyed by layer"
  value       = { for k, b in aws_s3_bucket.this : k => b.arn }
}

output "bronze_bucket_id" {
  description = "Bronze bucket ID"
  value       = aws_s3_bucket.this["bronze"].id
}

output "silver_bucket_id" {
  description = "Silver bucket ID"
  value       = aws_s3_bucket.this["silver"].id
}

output "gold_bucket_id" {
  description = "Gold bucket ID"
  value       = aws_s3_bucket.this["gold"].id
}

output "operations_bucket_id" {
  description = "Operations bucket ID"
  value       = aws_s3_bucket.this["operations"].id
}

output "artifacts_bucket_id" {
  description = "Artifacts bucket ID"
  value       = aws_s3_bucket.this["artifacts"].id
}

output "uri_map" {
  description = "Map of S3 URIs for all data layers and operational prefixes"
  value = {
    bronze     = "s3://${aws_s3_bucket.this["bronze"].id}/"
    silver     = "s3://${aws_s3_bucket.this["silver"].id}/"
    gold       = "s3://${aws_s3_bucket.this["gold"].id}/"
    operations = "s3://${aws_s3_bucket.this["operations"].id}/"
    artifacts  = "s3://${aws_s3_bucket.this["artifacts"].id}/"
    quarantine = "s3://${aws_s3_bucket.this["operations"].id}/quarantine/"
    evidence   = "s3://${aws_s3_bucket.this["operations"].id}/evidence/"
    benchmarks = "s3://${aws_s3_bucket.this["operations"].id}/benchmarks/"
    config     = "s3://${aws_s3_bucket.this["artifacts"].id}/config/"
    models     = "s3://${aws_s3_bucket.this["artifacts"].id}/models/"
    logs       = "s3://${aws_s3_bucket.this["artifacts"].id}/logs/"
    scripts    = "s3://${aws_s3_bucket.this["artifacts"].id}/scripts/"
  }
}
