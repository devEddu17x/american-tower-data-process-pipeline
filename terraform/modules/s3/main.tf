locals {
  bucket_definitions = {
    bronze = {
      description = "Raw ingested data from external sources"
      prefixes    = []
    }
    silver = {
      description = "Cleaned and normalized tabular datasets"
      prefixes    = []
    }
    gold = {
      description = "Integrated analytical tables ready for consumption and models"
      prefixes    = []
    }
    operations = {
      description = "Operational monitoring, quarantined records, evidence and benchmarks"
      prefixes    = ["quarantine/", "evidence/", "benchmarks/"]
    }
    artifacts = {
      description = "Versioned configurations, trained models, logs and bootstrap scripts"
      prefixes    = ["config/", "models/", "logs/", "scripts/"]
    }
  }

  # Flatten prefix list for object marker generation
  prefix_objects = merge([
    for b_key, b_val in local.bucket_definitions : {
      for p in b_val.prefixes : "${b_key}/${p}" => {
        bucket = b_key
        key    = p
      }
    }
  ]...)
}

# Dedicated S3 Buckets for each layer
resource "aws_s3_bucket" "this" {
  for_each = local.bucket_definitions

  bucket_prefix = "${var.project_name}-${var.environment}-${each.key}-"
  force_destroy = var.force_destroy

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-${each.key}"
      Layer       = each.key
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Block all public access by default for all buckets
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Default Server-Side Encryption (SSE-S3 AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning on each bucket
resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Folder prefix markers inside operational and artifact buckets
resource "aws_s3_object" "prefix_markers" {
  for_each = var.create_prefix_markers ? local.prefix_objects : {}

  bucket  = aws_s3_bucket.this[each.value.bucket].id
  key     = each.value.key
  content = ""
}
