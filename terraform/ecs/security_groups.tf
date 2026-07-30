# Security group for the public internet facing load balancer
resource "aws_security_group" "lb" {
  name        = "${terraform.workspace}-lb"
  description = "${terraform.workspace} load balancer security group"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-lb-sg"
  })
}

# Allow HTTP traffic from the public internet to the load balancer
resource "aws_security_group_rule" "lb-ingress-public" {
  description = "${terraform.workspace} load balancer ingress from public internet"
  type        = "ingress"

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.lb.id
}

# Allow HTTPS traffic from the public internet to the load balancer
resource "aws_security_group_rule" "lb-ingress-public-https" {
  description = "${terraform.workspace} load balancer ingress from public internet"
  type        = "ingress"

  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.lb.id
}

# Allow outbound traffic from the load balancer
resource "aws_security_group_rule" "lb-egress" {
  description = "${terraform.workspace} load balancer egress to the application"
  type        = "egress"

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.lb.id
}

# Security group for the application hosts
resource "aws_security_group" "app" {
  name        = "${terraform.workspace}-app"
  description = "${terraform.workspace} application security group"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-app-sg"
  })
}

# Allow traffic from the load balancer to the application hosts
resource "aws_security_group_rule" "app-ingress-from-lb" {
  description = "${terraform.workspace} application ingress from load balancer"
  type        = "ingress"

  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb.id

  security_group_id = aws_security_group.app.id
}

# Allow traffic from the load balancer to the application hosts
resource "aws_security_group_rule" "app-egress" {
  description = "${terraform.workspace} application ingress from load balancer"
  type        = "egress"

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.app.id
}
