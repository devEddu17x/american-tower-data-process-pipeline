terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

resource "time_sleep" "wait_for_iam_propagation" {
  create_duration = "${var.propagation_wait_seconds}s"

  triggers = {
    instance_profile_arn = var.instance_profile_arn
    service_role_arn     = var.service_role_arn
    dependencies         = join(",", var.iam_dependency_ids)
  }
}
