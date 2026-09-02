resource "aws_security_group" "emr_slave_sg" {
  name                   = "emr-slave-sg"
  description            = "Security group for EMR Core and Task nodes"
  vpc_id                 = aws_vpc.main.id
  revoke_rules_on_delete = true

  tags = {
    "for-use-with-amazon-emr-managed-policies" = "true"
  }
}

# Internal traffic from Master
resource "aws_vpc_security_group_ingress_rule" "slaves_from_master" {
  security_group_id            = aws_security_group.emr_slave_sg.id
  referenced_security_group_id = aws_security_group.emr_master_sg.id
  ip_protocol                  = "-1"
}

# Internal traffic within the Slave nodes
resource "aws_vpc_security_group_ingress_rule" "slaves_self" {
  security_group_id            = aws_security_group.emr_slave_sg.id
  referenced_security_group_id = aws_security_group.emr_slave_sg.id
  ip_protocol                  = "-1"
}

# Ingress to port 9443 from Service Access
resource "aws_vpc_security_group_ingress_rule" "slaves_from_service_access" {
  security_group_id            = aws_security_group.emr_slave_sg.id
  referenced_security_group_id = aws_security_group.emr_service_access_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 9443
  to_port                      = 9443
}

# Internet egress
resource "aws_vpc_security_group_egress_rule" "slaves_all_outbound" {
  security_group_id = aws_security_group.emr_slave_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
