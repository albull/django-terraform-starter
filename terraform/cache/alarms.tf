# Reference to shared SNS topic from common module
locals {
  alarms_sns_topic_arn = data.terraform_remote_state.common.outputs.alarms_sns_topic_arn
}

# Redis CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "redis_cpu_utilization" {
  alarm_name          = "${terraform.workspace}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Redis CPU utilization exceeded 80%"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.cache.replication_group_id}-001"
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-redis-cpu-alarm"
  })
}

# Redis Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "redis_memory_utilization" {
  alarm_name          = "${terraform.workspace}-redis-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Redis memory utilization exceeded 80%"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.cache.replication_group_id}-001"
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-redis-memory-alarm"
  })
}


# Redis Current Connections Alarm
resource "aws_cloudwatch_metric_alarm" "redis_current_connections" {
  alarm_name          = "${terraform.workspace}-redis-current-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "500"
  alarm_description   = "Redis current connections exceeded 500"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.cache.replication_group_id}-001"
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-redis-connections-alarm"
  })
}

# Redis Evictions Alarm
resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${terraform.workspace}-redis-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Redis evictions exceeded threshold"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.cache.replication_group_id}-001"
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-redis-evictions-alarm"
  })
}