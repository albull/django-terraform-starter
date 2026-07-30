# Reference to shared SNS topic from common module
locals {
  alarms_sns_topic_arn = data.terraform_remote_state.common.outputs.alarms_sns_topic_arn
}

# RDS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization" {
  alarm_name          = "${terraform.workspace}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "RDS CPU utilization exceeded 80%"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.database.identifier
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-rds-cpu-alarm"
  })
}

# RDS Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "rds_database_connections" {
  alarm_name          = "${terraform.workspace}-rds-database-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "RDS database connections exceeded 80% of maximum"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.database.identifier
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-rds-connections-alarm"
  })
}

# RDS Free Storage Space Alarm
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_space" {
  alarm_name          = "${terraform.workspace}-rds-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2147483648" # 2GB in bytes (20% of 10GB minimum)
  alarm_description   = "RDS free storage space is below 2GB"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.database.identifier
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-rds-storage-alarm"
  })
}

# RDS Read Latency Alarm
resource "aws_cloudwatch_metric_alarm" "rds_read_latency" {
  alarm_name          = "${terraform.workspace}-rds-read-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.2"
  alarm_description   = "RDS read latency exceeded 200ms"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.database.identifier
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-rds-read-latency-alarm"
  })
}

# RDS Write Latency Alarm
resource "aws_cloudwatch_metric_alarm" "rds_write_latency" {
  alarm_name          = "${terraform.workspace}-rds-write-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.2"
  alarm_description   = "RDS write latency exceeded 200ms"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.database.identifier
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-rds-write-latency-alarm"
  })
}

# RDS Free Memory Alarm
resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory" {
  alarm_name          = "${terraform.workspace}-rds-freeable-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "67108864" # 64MB in bytes
  alarm_description   = "RDS freeable memory is below 64MB"
  alarm_actions       = [local.alarms_sns_topic_arn]
  ok_actions          = [local.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.database.identifier
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-rds-memory-alarm"
  })
}