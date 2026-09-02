resource "aws_security_group" "emr_service_access_sg" {
  name        = "emr-service-access-sg"
  description = "Security group for EMR control plane access"
  vpc_id      = aws_vpc.main.id
}

# Ingress to port 9443 from Master
resource "aws_vpc_security_group_ingress_rule" "service_access_from_master" {
  security_group_id            = aws_security_group.emr_service_access_sg.id
  referenced_security_group_id = aws_security_group.emr_master_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 9443
  to_port                      = 9443
}

# Egress to port 9443 towards Master
resource "aws_vpc_security_group_egress_rule" "service_access_to_master" {
  security_group_id            = aws_security_group.emr_service_access_sg.id
  referenced_security_group_id = aws_security_group.emr_master_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 9443
  to_port                      = 9443
}
