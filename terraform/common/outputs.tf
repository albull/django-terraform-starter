output "module_name" {
  value = local.module_name
}

output "default_tags" {
  value = local.default_tags
}

output "alarms_sns_topic_arn" {
  value = aws_sns_topic.alarms.arn
}