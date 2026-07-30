locals {
  # Truncate the workspace name if it's too long for AWS resource naming
  # AWS ALB names have a limit of 32 characters
  truncated_workspace = length(terraform.workspace) > 28 ? substr(terraform.workspace, 0, 28) : terraform.workspace
  lb_name             = "${local.truncated_workspace}-app"
}

# The application will be reachable from the public internet via a public ALB
resource "aws_lb" "app" {
  name               = local.lb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = data.terraform_remote_state.network.outputs.public_subnet_ids
  idle_timeout       = 3600

  access_logs {
    bucket  = aws_s3_bucket.lb-logs.id
    enabled = true
  }
}

# Logging
resource "aws_s3_bucket" "lb-logs" {
  bucket        = "${terraform.workspace}-lb-access-logs"
  force_destroy = true

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-lb-access-logs"
  })
}

# Objects in this bucket will be private
resource "aws_s3_bucket_public_access_block" "lb-logs" {
  bucket = aws_s3_bucket.lb-logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [
    aws_s3_bucket.lb-logs
  ]
}

resource "aws_s3_bucket_versioning" "versioning-lb-logs" {
  bucket = aws_s3_bucket.lb-logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Account id of the AWS ALB and ELB service account in the given region
data "aws_elb_service_account" "main" {}

# Allow the ALB to write logs to the bucket
resource "aws_s3_bucket_policy" "lb-logs" {
  bucket = aws_s3_bucket.lb-logs.id
  policy = jsonencode({
    Id = "AccessLogsPolicy"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:PutObject"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Resource = "${aws_s3_bucket.lb-logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Sid      = "AllowWriteFromLoadBalancerAccount"
      },
      {
        Action = "s3:PutObject"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Resource = "${aws_s3_bucket.lb-logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Sid      = "AWSLogDeliveryWrite"
      },
      {
        Action = "s3:GetBucketAcl"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Resource = aws_s3_bucket.lb-logs.arn
        Sid      = "AWSLogDeliveryAclCheck"
      },
    ]
    Version = "2012-10-17"
  })
}

# Routing
resource "aws_lb_target_group" "app" {
  name                 = local.lb_name
  port                 = var.app_port
  protocol             = "HTTP"
  deregistration_delay = 300
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  target_type          = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/ping/"
    timeout             = 10
    port                = "traffic-port"
    protocol            = "HTTP"
    unhealthy_threshold = 5
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  depends_on = [
    aws_lb.app
  ]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-lb-target-group"
  })
}

# The default route will point all traffic to the target group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-lb-listener-http"
  })
}
