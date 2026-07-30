# AWS WAF v2 Web ACL for Application Load Balancer
resource "aws_wafv2_web_acl" "main" {
  name  = "${terraform.workspace}-web-acl"
  scope = "REGIONAL" # Use REGIONAL for ALB, CLOUDFRONT for CloudFront

  default_action {
    allow {}
  }

  # AWS Managed Rule: Known Bad Inputs (Priority 0)
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule: SQL Injection (Priority 1)
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Geo Block: Non-US traffic (Priority 2)
  rule {
    name     = "GeoBlockNonUS"
    priority = 2

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["US"]
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockNonUSMetric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule: IP Reputation List (Priority 4)
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationListMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${terraform.workspace}WebACL"
    sampled_requests_enabled   = true
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-web-acl"
  })
}

# Associate WAF with Application Load Balancer
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# CloudWatch Log Group for WAF logs (must start with aws-waf-logs-)
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${data.aws_region.current.name}-${terraform.workspace}"
  retention_in_days = 30

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-waf-log-group"
  })
}

# CloudWatch Log Resource Policy for WAF (required for permissions)
resource "aws_cloudwatch_log_resource_policy" "waf" {
  policy_name = "${terraform.workspace}-waf-log-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.waf.arn}:*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  depends_on = [aws_cloudwatch_log_resource_policy.waf]

  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}