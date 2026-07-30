locals {
  module_name = "cache"
  default_tags = {
    Workspace = terraform.workspace
    Module    = local.module_name
    Terraform = "true"
  }
}

data "aws_vpc" "main" {
  id         = data.terraform_remote_state.network.outputs.vpc_id
  cidr_block = data.terraform_remote_state.network.outputs.vpc_cidr_block
}

resource "aws_security_group" "cache" {
  name        = "${terraform.workspace}-cache"
  description = "${terraform.workspace} cache security group"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "Allow traffic from VPC to Redis"
    from_port   = var.redis_port
    to_port     = var.redis_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "Allow traffic from Redis to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-cache-sg"
  })
}

resource "aws_elasticache_subnet_group" "cache" {
  name        = "${terraform.workspace}-cache-subnet-group"
  description = "${terraform.workspace} cache subnet group"
  subnet_ids  = data.terraform_remote_state.network.outputs.private_subnet_ids

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-cache-subnet-group"
  })
}

locals {
  # Truncate the workspace name if it's too long for AWS resource naming
  # AWS ALB names have a limit of 32 characters
  truncated_workspace = length(terraform.workspace) > 20 ? substr(terraform.workspace, 0, 20) : terraform.workspace
  redis_name          = local.truncated_workspace
}

resource "aws_elasticache_replication_group" "cache" {
  replication_group_id       = "${local.redis_name}-redis-replica-cache"
  description                = "${terraform.workspace} Redis group cache"
  engine                     = "redis"
  node_type                  = var.redis_instance_class
  num_cache_clusters         = 1
  parameter_group_name       = "default.redis7"
  engine_version             = "7.1"
  port                       = 6379
  security_group_ids         = [aws_security_group.cache.id]
  subnet_group_name          = aws_elasticache_subnet_group.cache.name
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = merge(local.default_tags, {
    Name = "${local.redis_name}-redis-replica-cache"
  })
}

