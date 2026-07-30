# Shared SNS Topic for CloudWatch Alarms across all modules
resource "aws_sns_topic" "alarms" {
  name = "${terraform.workspace}-alarms"

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-alarms-topic"
  })
}

# SNS Topic Policy to allow CloudWatch to publish
resource "aws_sns_topic_policy" "alarms_policy" {
  arn = aws_sns_topic.alarms.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alarms.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Email subscription to SNS topic
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = "alarms@example.com"
}