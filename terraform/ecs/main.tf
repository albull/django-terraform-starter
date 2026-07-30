locals {
  module_name = "ecs"
  default_tags = {
    Workspace = terraform.workspace
    Module    = local.module_name
    Terraform = "true"
  }
}

# A cluster of Docker containers
resource "aws_ecs_cluster" "web" {
  name = "${terraform.workspace}-web"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-web"
  })
}

resource "aws_ecs_service" "web" {
  name                   = "${terraform.workspace}-web"
  cluster                = aws_ecs_cluster.web.id
  task_definition        = aws_ecs_task_definition.app.arn
  desired_count          = var.service_desired_web_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${terraform.workspace}-app"
    container_port   = var.app_port
  }

  network_configuration {
    subnets         = data.terraform_remote_state.network.outputs.private_subnet_ids
    security_groups = [aws_security_group.app.id]
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-web-ecs-service"
  })
}

data "aws_region" "current" {}

locals {
  # Always use 'latest' image tag for cross-account compatibility
  image_tag = "latest"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${terraform.workspace}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.app_cpu
  memory                   = var.app_memory
  runtime_platform {
    cpu_architecture = "X86_64"
  }
  task_role_arn      = aws_iam_role.app-task.arn
  execution_role_arn = aws_iam_role.app-task-execution.arn

  container_definitions = jsonencode([
    {
      name        = "${terraform.workspace}-app"
      image       = "${var.ecr_repository_url}:${local.image_tag}"
      cpu         = var.app_cpu
      memory      = var.app_memory
      stopTimeout = 120
      mountPoints = []
      volumesFrom = []
      essential   = true
      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
        }
      ]

      networkMode = "awsvpc"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "${terraform.workspace}-app"
        }
      }

      environment = [
        {
          name  = "ENV"
          value = var.django_env
        },
        {
          name  = "DEBUG"
          value = "0"
        },
        {
          name  = "ALLOWED_HOSTS"
          value = "${aws_lb.app.dns_name},${var.zone_name},${var.domain_name},localhost,10.0.*"
        },
        {
          name  = "DATABASE_HOST"
          value = data.terraform_remote_state.rds.outputs.rds_address
        },
        {
          name  = "DATABASE_PORT"
          value = tostring(data.terraform_remote_state.rds.outputs.rds_port)
        },
        {
          name  = "DATABASE_NAME"
          value = data.terraform_remote_state.rds.outputs.database_name
        },
        {
          name  = "DATABASE_USER"
          value = data.terraform_remote_state.rds.outputs.master_user_name
        },
        {
          name  = "DOMAIN"
          value = var.zone_name
        },
        {
          name  = "REDIS_URL"
          value = "rediss://${data.terraform_remote_state.cache.outputs.redis_host1_address}:6379/0"
        },
        {
          name  = "AWS_STORAGE_BUCKET_NAME"
          value = aws_s3_bucket.storage.bucket
        },
        {
          name  = "AWS_S3_REGION_NAME"
          value = data.aws_region.current.name
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = data.aws_region.current.name
        },
        {
          name  = "USE_S3"
          value = "true"
        }
      ]

      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = data.terraform_remote_state.rds.outputs.db_password_ssm_parameter_name
        },
        {
          name      = "DJANGO_SECRET_KEY"
          valueFrom = aws_ssm_parameter.django_secret_key.name
        }
      ]
    }
  ])

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-task-definition"
  })
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "${terraform.workspace}-app"
  retention_in_days = 30

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-log-group"
  })
}

resource "aws_iam_role" "app-task-execution" {
  name = "${terraform.workspace}-app-task-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-app-task-execution"
  })
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app-task-execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_kms_key" "default-ssm-key" {
  key_id = "alias/aws/ssm"
}

data "sops_file" "secrets" {
  source_file = "vars/${terraform.workspace}-secrets.json"
}

resource "aws_ssm_parameter" "django_secret_key" {
  name  = "/${terraform.workspace}/django/secret_key"
  type  = "SecureString"
  value = data.sops_file.secrets.data["DJANGO_SECRET_KEY"]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-django-secret-key"
  })
}

data "aws_ssm_parameter" "database_password" {
  name = data.terraform_remote_state.rds.outputs.db_password_ssm_parameter_name
}

resource "aws_ssm_parameter" "database_url" {
  name  = "/${terraform.workspace}/django/database_url"
  type  = "SecureString"
  value = "postgres://${data.terraform_remote_state.rds.outputs.master_user_name}:${data.aws_ssm_parameter.database_password.value}@${data.terraform_remote_state.rds.outputs.rds_address}:${data.terraform_remote_state.rds.outputs.rds_port}/${data.terraform_remote_state.rds.outputs.database_name}"

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-database-url"
  })
}

# Used for looking up our own account ID
data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "secrets-for-docker" {
  name = "${terraform.workspace}-container-secrets"
  role = aws_iam_role.app-task-execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.database_url.arn,
          aws_ssm_parameter.django_secret_key.arn,
          data.aws_ssm_parameter.database_password.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          data.aws_kms_key.default-ssm-key.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "app-task" {
  name = "${terraform.workspace}-app-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-app-task"
  })
}

resource "aws_s3_bucket" "storage" {
  bucket        = "${terraform.workspace}-app-storage"
  force_destroy = true

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-app-storage"
  })
}

resource "aws_s3_bucket_public_access_block" "storage" {
  bucket = aws_s3_bucket.storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket_policy.storage]
}

resource "aws_s3_bucket_versioning" "versioning-storage" {
  bucket = aws_s3_bucket.storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "storage" {
  bucket = aws_s3_bucket.storage.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedTransit"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.storage.arn}/*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "storage" {
  name = "${terraform.workspace}-storage"
  role = aws_iam_role.app-task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "AppStoragePolicy"
    Statement = [
      {
        Action = "s3:*"
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*"
        ]
      }
    ]
  })
}

# Policy to allow ECS Exec functionality
resource "aws_iam_role_policy" "ecs-exec" {
  name = "${terraform.workspace}-ecs-exec"
  role = aws_iam_role.app-task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch-metrics" {
  name = "${terraform.workspace}-cloudwatch-metrics"
  role = aws_iam_role.app-task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "App/Celery"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_cors_configuration" "storage-cors" {
  bucket = aws_s3_bucket.storage.id

  # CORS rule for uploading files (PUT operations)
  cors_rule {
    allowed_headers = ["Content-Type", "Content-MD5", "Content-Disposition", "x-amz-server-side-encryption"]
    allowed_methods = ["PUT", "HEAD"]
    allowed_origins = ["https://${var.zone_name}"]
    max_age_seconds = 300
  }

  # CORS rule for audio file playback (GET operations)
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = concat(
      ["https://${var.zone_name}"],
      var.django_env == "prod" ? [] : ["http://localhost:8000"]
    )
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}
