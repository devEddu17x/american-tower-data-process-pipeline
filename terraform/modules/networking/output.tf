output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public_a.id
}

output "emr_master_sg_id" {
  value = aws_security_group.emr_master_sg.id
}

output "emr_slave_sg_id" {
  value = aws_security_group.emr_slave_sg.id
}

output "emr_service_access_sg_id" {
  value = aws_security_group.emr_service_access_sg.id
}
