output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket storing Terraform remote state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "backend_hcl_snippet" {
  description = "Content to place into envs/dev/backend.hcl for terraform init -backend-config=backend.hcl"
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.terraform_state.id}"
    key          = "dev/terraform.tfstate"
    region       = "${var.aws_region}"
    profile      = "${var.aws_profile}"
    use_lockfile = true
    encrypt      = true
  EOT
}
