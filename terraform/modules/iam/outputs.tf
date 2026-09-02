output "emr_service_role_arn" {
  description = "ARN of the EMR service IAM role"
  value       = aws_iam_role.emr_service_role.arn
}

output "emr_service_role_name" {
  description = "Name of the EMR service IAM role"
  value       = aws_iam_role.emr_service_role.name
}

output "emr_ec2_role_arn" {
  description = "ARN of the EMR EC2 IAM role"
  value       = aws_iam_role.emr_ec2_role.arn
}

output "emr_ec2_role_name" {
  description = "Name of the EMR EC2 IAM role"
  value       = aws_iam_role.emr_ec2_role.name
}

output "emr_ec2_instance_profile_arn" {
  description = "ARN of the EMR EC2 instance profile"
  value       = aws_iam_instance_profile.emr_ec2_profile.arn
}

output "emr_ec2_instance_profile_name" {
  description = "Name of the EMR EC2 instance profile"
  value       = aws_iam_instance_profile.emr_ec2_profile.name
}

output "iam_dependency_ids" {
  description = "IDs of IAM attachments and instance profile to explicitly chain dependencies"
  value = [
    aws_iam_role_policy_attachment.emr_service_policy.id,
    aws_iam_role_policy.emr_service_pass_role.id,
    aws_iam_role_policy_attachment.emr_ec2_role_policy.id,
    aws_iam_role_policy_attachment.emr_ec2_s3_policy.id,
    aws_iam_instance_profile.emr_ec2_profile.id
  ]
}

