# Reference to shared SNS topic from common module
locals {
  alarms_sns_topic_arn = data.terraform_remote_state.common.outputs.alarms_sns_topic_arn
}

# ALB 400 Bad Request Alarm (Moderate Threshold - Malformed Requests)
resource "aws_cloudwatch_metric_alarm" "alb_400_errors" {
  alarm_name          = "${terraform.workspace}-alb-400-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_400_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "ALB 400 Bad Request errors exceeded threshold"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-alb-400-errors-alarm"
  })
}

# ALB 401/422 Error Alarm (Immediate - Auth/Validation Issues)
resource "aws_cloudwatch_metric_alarm" "alb_auth_validation_errors" {
  alarm_name          = "${terraform.workspace}-alb-auth-validation-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_401_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "ALB 401/422 errors detected (auth/validation issues)"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-alb-auth-validation-errors-alarm"
  })
}

# ALB 403 Forbidden Alarm (High Threshold - Disallowed Hosts/Attacks)
resource "aws_cloudwatch_metric_alarm" "alb_403_errors" {
  alarm_name          = "${terraform.workspace}-alb-403-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_403_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "25"
  alarm_description   = "ALB 403 Forbidden errors exceeded threshold (disallowed hosts/attacks)"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-alb-403-errors-alarm"
  })
}

# ALB 404 Not Found Alarm (Moderate Threshold - Broken Links)
resource "aws_cloudwatch_metric_alarm" "alb_404_errors" {
  alarm_name          = "${terraform.workspace}-alb-404-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_404_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "ALB 404 Not Found errors exceeded threshold"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-alb-404-errors-alarm"
  })
}

# ALB 5xx Error Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${terraform.workspace}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "ALB 5xx errors detected"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-alb-5xx-alarm"
  })
}

# ALB Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${terraform.workspace}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "ALB response time exceeded 2 seconds"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-alb-response-time-alarm"
  })
}

# ALB Healthy Host Count Alarm
resource "aws_cloudwatch_metric_alarm" "alb_healthy_hosts" {
  alarm_name          = "${terraform.workspace}-alb-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "ALB has less than 1 healthy host"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.app.arn_suffix
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-alb-healthy-hosts-alarm"
  })
}

# ECS Service CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "${terraform.workspace}-ecs-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS service CPU utilization exceeded 80%"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.web.name
    ClusterName = aws_ecs_cluster.web.name
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-cpu-alarm"
  })
}

# ECS Service Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "${terraform.workspace}-ecs-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS service memory utilization exceeded 80%"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.web.name
    ClusterName = aws_ecs_cluster.web.name
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-memory-alarm"
  })
}

# ECS Service Running Task Count Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks" {
  alarm_name          = "${terraform.workspace}-ecs-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "ECS service has less than 1 running task"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = aws_ecs_service.web.name
    ClusterName = aws_ecs_cluster.web.name
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-running-tasks-alarm"
  })
}

# Application Error Log Alarm (Django ERROR level)
resource "aws_cloudwatch_metric_alarm" "app_error_logs" {
  alarm_name          = "${terraform.workspace}-app-error-logs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ErrorLogCount"
  namespace           = "CWLogs"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Application ERROR logs detected"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-app-error-logs-alarm"
  })
}

# Application Critical Log Alarm (Django CRITICAL level)
resource "aws_cloudwatch_metric_alarm" "app_critical_logs" {
  alarm_name          = "${terraform.workspace}-app-critical-logs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CriticalLogCount"
  namespace           = "CWLogs"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Application CRITICAL logs detected"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-app-critical-logs-alarm"
  })
}

# Metric filters for log-based alarms
resource "aws_cloudwatch_log_metric_filter" "error_logs_filter" {
  name           = "${terraform.workspace}-error-logs-filter"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"

  metric_transformation {
    name      = "ErrorLogCount"
    namespace = "CWLogs"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "critical_logs_filter" {
  name           = "${terraform.workspace}-critical-logs-filter"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "[timestamp, request_id, level=\"CRITICAL\", ...]"

  metric_transformation {
    name      = "CriticalLogCount"
    namespace = "CWLogs"
    value     = "1"
  }
}

# ================================
# JOBS CLUSTER ALARMS
# ================================

# ECS Jobs Cluster CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_jobs_cpu_utilization" {
  alarm_name          = "${terraform.workspace}-ecs-jobs-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS jobs service CPU utilization exceeded 80%"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.jobs.name
    ClusterName = aws_ecs_cluster.jobs.name
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-jobs-cpu-alarm"
  })
}

# ECS Jobs Cluster Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_jobs_memory_utilization" {
  alarm_name          = "${terraform.workspace}-ecs-jobs-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS jobs service memory utilization exceeded 80%"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = aws_ecs_service.jobs.name
    ClusterName = aws_ecs_cluster.jobs.name
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-jobs-memory-alarm"
  })
}

# ECS Jobs Service Running Task Count Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_jobs_running_tasks" {
  alarm_name          = "${terraform.workspace}-ecs-jobs-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "ECS jobs service has less than 1 running task"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = aws_ecs_service.jobs.name
    ClusterName = aws_ecs_cluster.jobs.name
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-jobs-running-tasks-alarm"
  })
}

# Jobs Error Log Alarm (Django ERROR level in jobs logs)
resource "aws_cloudwatch_metric_alarm" "jobs_error_logs" {
  alarm_name          = "${terraform.workspace}-jobs-error-logs"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "JobsErrorLogCount"
  namespace           = "CWLogs"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Jobs ERROR logs detected"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-jobs-error-logs-alarm"
  })
}

# Jobs Critical Log Alarm (Django CRITICAL level in jobs logs)
resource "aws_cloudwatch_metric_alarm" "jobs_critical_logs" {
  alarm_name          = "${terraform.workspace}-jobs-critical-logs"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "JobsCriticalLogCount"
  namespace           = "CWLogs"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Jobs CRITICAL logs detected"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-jobs-critical-logs-alarm"
  })
}

# Celery Worker Health Alarm (failed tasks)
resource "aws_cloudwatch_metric_alarm" "celery_failed_tasks" {
  alarm_name          = "${terraform.workspace}-celery-failed-tasks"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CeleryFailedTaskCount"
  namespace           = "CWLogs"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Celery failed tasks exceeded threshold"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-celery-failed-tasks-alarm"
  })
}

# Metric filters for jobs log-based alarms
resource "aws_cloudwatch_log_metric_filter" "jobs_error_logs_filter" {
  name           = "${terraform.workspace}-jobs-error-logs-filter"
  log_group_name = aws_cloudwatch_log_group.jobs.name
  pattern        = "ERROR"

  metric_transformation {
    name      = "JobsErrorLogCount"
    namespace = "CWLogs"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "jobs_critical_logs_filter" {
  name           = "${terraform.workspace}-jobs-critical-logs-filter"
  log_group_name = aws_cloudwatch_log_group.jobs.name
  pattern        = "CRITICAL"

  metric_transformation {
    name      = "JobsCriticalLogCount"
    namespace = "CWLogs"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "celery_failed_tasks_filter" {
  name           = "${terraform.workspace}-celery-failed-tasks-filter"
  log_group_name = aws_cloudwatch_log_group.jobs.name
  pattern        = "raised unexpected"

  metric_transformation {
    name      = "CeleryFailedTaskCount"
    namespace = "CWLogs"
    value     = "1"
  }
}

# ================================
# WAF ALARMS
# ================================

# WAF Blocked Requests Alarm (High Volume)
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${terraform.workspace}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "High volume of blocked requests detected by WAF"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Rule   = "ALL"
    Region = data.aws_region.current.name
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-waf-blocked-requests-alarm"
  })
}

# WAF SQL Injection Attempts Alarm
resource "aws_cloudwatch_metric_alarm" "waf_sqli_attempts" {
  alarm_name          = "${terraform.workspace}-waf-sqli-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "SQL injection attempts detected by WAF"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Rule   = "AWS-AWSManagedRulesSQLiRuleSet"
    Region = data.aws_region.current.name
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-waf-sqli-alarm"
  })
}