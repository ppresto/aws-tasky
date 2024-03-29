resource "aws_security_group" "mongo" {
  count       = var.security_group_create == true ? 1 : 0
  name_prefix = var.name_prefix
  description = "Mongo DB Security group."
  vpc_id      = var.vpc_id
  tags = merge(
    { "Name" = "${var.name_prefix}" },
    { "Owner" = "presto" }
  )
}

resource "aws_security_group_rule" "mongoPort" {
  security_group_id = var.security_group_create == true ? aws_security_group.mongo[0].id : var.security_group_id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 27017
  to_port           = 27017
  cidr_blocks       = var.vpc_cidr_blocks
  description       = "Mongo DB default port"
}

resource "aws_security_group_rule" "all-outbound" {
  security_group_id = var.security_group_create == true ? aws_security_group.mongo[0].id : var.security_group_id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Egress all traffic"
}