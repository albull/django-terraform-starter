# AWS Backup vault for PHI data retention (6 years for HIPAA compliance)
resource "aws_backup_vault" "phi_backup_vault" {
  name        = "${terraform.workspace}-phi-backup-vault"
  kms_key_arn = aws_kms_key.rds_key.arn

  tags = merge(local.default_tags, {
    Name    = "${terraform.workspace}-phi-backup-vault"
    Purpose = "HIPAA-PHI-Compliance"
  })
}

# IAM role for AWS Backup
resource "aws_iam_role" "backup_role" {
  name = "${terraform.workspace}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-backup-role"
  })
}

# Attach AWS managed backup policy
resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Attach restore policy
resource "aws_iam_role_policy_attachment" "restore_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Backup plan for PHI data (exactly 6 years = 2190 days for HIPAA compliance)
resource "aws_backup_plan" "phi_backup_plan" {
  name = "${terraform.workspace}-phi-backup-plan"

  # Daily backups retained for exactly 6 years (2190 days)
  rule {
    rule_name         = "phi-daily-backup-6-years"
    target_vault_name = aws_backup_vault.phi_backup_vault.name
    schedule          = "cron(0 4 * * ? *)" # Daily at 4 AM UTC (after RDS backup window)

    lifecycle {
      cold_storage_after = 30   # Move to cold storage after 30 days for cost optimization
      delete_after       = 2190 # Exactly 6 years (2190 days) for HIPAA compliance
    }

    recovery_point_tags = merge(local.default_tags, {
      BackupType = "PHI-Daily"
      Purpose    = "HIPAA-Compliance"
      DataType   = "PHI"
    })
  }

  tags = merge(local.default_tags, {
    Name    = "${terraform.workspace}-phi-backup-plan"
    Purpose = "HIPAA-PHI-Compliance"
  })
}

# Backup selection for PHI-tagged RDS instances only
resource "aws_backup_selection" "phi_backup_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "${terraform.workspace}-phi-backup-selection"
  plan_id      = aws_backup_plan.phi_backup_plan.id

  # Explicitly list RDS instances with PHI data
  resources = concat(
    [aws_db_instance.database.arn],
    var.analytics_replica ? [aws_db_instance.database-read-replica-analytics[0].arn] : []
  )

  # Only backup RDS instances tagged with PHI=true
  condition {
    string_equals {
      key   = "aws:ResourceTag/PHI"
      value = "true"
    }
  }
}

# CloudWatch alarm for backup job failures
resource "aws_cloudwatch_metric_alarm" "backup_job_failed" {
  alarm_name          = "${terraform.workspace}-backup-job-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfBackupJobsFailed"
  namespace           = "AWS/Backup"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "RDS backup job failed"
  alarm_actions       = [data.terraform_remote_state.common.outputs.alarms_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    BackupVaultName = aws_backup_vault.phi_backup_vault.name
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-backup-job-failed-alarm"
  })
}