output "cluster_id" {
  description = "ID of the created EMR cluster"
  value       = aws_emr_cluster.cluster.id
}

output "master_public_dns" {
  description = "Public DNS name of the Master node"
  value       = aws_emr_cluster.cluster.master_public_dns
}

output "ssh_connection_string" {
  description = "Command to connect via SSH to the Master node"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem hadoop@${aws_emr_cluster.cluster.master_public_dns}"
}
