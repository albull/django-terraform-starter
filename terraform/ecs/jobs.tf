resource "aws_ecs_cluster" "jobs" {
  name = "${terraform.workspace}-jobs"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-jobs"
  })
}

# Task definition specifically for Celery workers
resource "aws_ecs_task_definition" "jobs" {
  family                   = "${terraform.workspace}-jobs"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.jobs_cpu
  memory                   = var.jobs_memory
  runtime_platform {
    cpu_architecture = "X86_64"
  }
  task_role_arn      = aws_iam_role.app-task.arn
  execution_role_arn = aws_iam_role.app-task-execution.arn

  container_definitions = jsonencode([
    {
      name        = "${terraform.workspace}-jobs"
      image       = "${var.ecr_repository_url}:latest"
      cpu         = var.jobs_cpu
      memory      = var.jobs_memory
      stopTimeout = 120
      mountPoints = []
      volumesFrom = []
      essential   = true

      # Override the default command to run Celery worker
      command = [
        "jobs"
      ]

      networkMode = "awsvpc"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.jobs.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "${terraform.workspace}-jobs"
        }
      }

      # Same environment variables as web container
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
          name  = "REDIS_URL"
          value = "rediss://${data.terraform_remote_state.cache.outputs.redis_host1_address}:6379/0"
        },
        {
          name  = "DOMAIN"
          value = var.zone_name
        },
        {
          name  = "DJANGO_SETTINGS_MODULE"
          value = "config.settings"
        },
        {
          name  = "C_FORCE_ROOT"
          value = "1"
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

      # Same secrets as web container
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

      # Health check for Celery workers
      healthCheck = {
        command = [
          "CMD-SHELL",
          "celery -A config inspect ping -d celery@$HOSTNAME || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-jobs-ecs-task-definition"
  })
}

# CloudWatch log group for jobs
resource "aws_cloudwatch_log_group" "jobs" {
  name              = "${terraform.workspace}-jobs"
  retention_in_days = 30

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-jobs-log-group"
  })
}

# Service will keep a desired amount of Celery workers always running
resource "aws_ecs_service" "jobs" {
  name                   = "${terraform.workspace}-jobs"
  cluster                = aws_ecs_cluster.jobs.id
  task_definition        = aws_ecs_task_definition.jobs.arn
  desired_count          = var.service_desired_job_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets         = data.terraform_remote_state.network.outputs.private_subnet_ids
    security_groups = [aws_security_group.app.id]
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-jobs-ecs-service"
  })
}
