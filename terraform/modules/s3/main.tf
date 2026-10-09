resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  bucket_prefix = var.bucket_name == null ? "${var.project_name}-${var.environment}-datalake-" : null
  force_destroy = var.force_destroy

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-datalake"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Block all public access by default
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Default Server-Side Encryption (SSE-S3 AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket Versioning
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Folder prefix markers conforming to Data Lake layout
resource "aws_s3_object" "prefix_markers" {
  for_each = var.create_prefix_markers ? toset(var.initial_prefixes) : toset([])

  bucket  = aws_s3_bucket.this.id
  key     = each.value
  content = ""
}

