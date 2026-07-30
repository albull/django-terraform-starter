locals {
  module_name = "rds"
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

resource "aws_security_group" "database" {
  name        = "${terraform.workspace}-database-sg"
  description = "DB security group"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    from_port   = var.rds_port
    to_port     = var.rds_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-database-sg"
  })
}

resource "aws_security_group_rule" "rds-quicksight-ingress" {
  count             = var.analytics_replica ? 1 : 0
  type              = "ingress"
  description       = "Allow Quicksight to access the database"
  from_port         = var.rds_port
  to_port           = var.rds_port
  protocol          = "tcp"
  cidr_blocks       = [data.terraform_remote_state.common.outputs.quicksight_vpc_cidr_block]
  security_group_id = aws_security_group.database.id
}

resource "aws_security_group_rule" "rds-analytics-egress" {
  count             = var.analytics_replica ? 1 : 0
  type              = "egress"
  description       = "Allow traffic from RDS to Quicksight"
  from_port         = var.rds_port
  to_port           = var.rds_port
  protocol          = "tcp"
  cidr_blocks       = [data.terraform_remote_state.common.outputs.quicksight_vpc_cidr_block]
  security_group_id = aws_security_group.database.id
}

resource "aws_db_subnet_group" "main" {
  name        = "${terraform.workspace}-database-subnet-group"
  description = "DB subnet group"
  subnet_ids  = data.terraform_remote_state.network.outputs.private_subnet_ids

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-database-subnet-group"
  })
}

resource "aws_kms_key" "rds_key" {
  description = "KMS key for RDS"

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-database-kms-key"
  })
}

resource "aws_kms_alias" "rds_key_alias" {
  name          = "alias/${terraform.workspace}-rds-kms-alias"
  target_key_id = aws_kms_key.rds_key.key_id
}

resource "aws_db_parameter_group" "database" {
  name_prefix = "${terraform.workspace}-database-parameter-group-"
  family      = "postgres14"
  description = "DB parameter group"

  dynamic "parameter" {
    for_each = var.parameter_group_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-database-parameter-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

data "sops_file" "secrets" {
  source_file = "vars/${terraform.workspace}-secrets.json"
}

resource "aws_db_instance" "database" {
  identifier                          = "${terraform.workspace}-database"
  allocated_storage                   = var.allocated_storage
  max_allocated_storage               = var.max_allocated_storage
  storage_type                        = "gp3"
  skip_final_snapshot                 = var.skip_final_snapshot
  engine                              = "postgres"
  engine_version                      = "14.17"
  allow_major_version_upgrade         = true
  instance_class                      = var.instance_class
  db_name                             = var.db_name
  username                            = var.username
  password                            = data.sops_file.secrets.data["rds_master_password"]
  port                                = var.rds_port
  maintenance_window                  = var.maintenance_window
  backup_window                       = var.backup_window
  backup_retention_period             = var.backup_retention_period
  vpc_security_group_ids              = [aws_security_group.database.id]
  db_subnet_group_name                = aws_db_subnet_group.main.name
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  deletion_protection                 = true
  kms_key_id                          = aws_kms_key.rds_key.arn
  performance_insights_enabled        = true
  performance_insights_kms_key_id     = aws_kms_key.rds_key.arn
  parameter_group_name                = aws_db_parameter_group.database.name
  enabled_cloudwatch_logs_exports     = ["postgresql"]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-database"
    PHI  = "true"
  })
}

resource "aws_db_instance" "database-read-replica-analytics" {
  count                               = var.analytics_replica ? 1 : 0
  identifier                          = "${terraform.workspace}-database-read-replica-analytics"
  replicate_source_db                 = aws_db_instance.database.identifier
  instance_class                      = var.instance_class
  vpc_security_group_ids              = [aws_security_group.database.id]
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  deletion_protection                 = true
  kms_key_id                          = aws_kms_key.rds_key.arn
  performance_insights_enabled        = true
  performance_insights_kms_key_id     = aws_kms_key.rds_key.arn
  parameter_group_name                = aws_db_parameter_group.database.name

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-database-read-replica-analytics"
    PHI  = "true"
  })
}

resource "aws_ssm_parameter" "rds_master_password" {
  name  = "/${terraform.workspace}/rds/master_password"
  type  = "SecureString"
  value = data.sops_file.secrets.data["rds_master_password"]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-rds-master-password"
  })
}
