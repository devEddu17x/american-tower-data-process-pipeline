output "instance_profile_arn" {
  description = "Propagated IAM instance profile ARN"
  value       = var.instance_profile_arn
  depends_on  = [time_sleep.wait_for_iam_propagation]
}

output "instance_profile_name" {
  description = "Propagated IAM instance profile name"
  value       = var.instance_profile_name
  depends_on  = [time_sleep.wait_for_iam_propagation]
}

output "service_role_arn" {
  description = "Propagated IAM service role ARN"
  value       = var.service_role_arn
  depends_on  = [time_sleep.wait_for_iam_propagation]
}

output "service_role_name" {
  description = "Propagated IAM service role name"
  value       = var.service_role_name
  depends_on  = [time_sleep.wait_for_iam_propagation]
}
