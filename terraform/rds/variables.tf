variable "state_bucket" {
  type        = string
  description = "The S3 bucket for storing the Terraform state"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage for the RDS instance"
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum allocated storage for the RDS instance"
}

variable "instance_class" {
  type        = string
  description = "The instance class for the RDS instance"
}

variable "db_name" {
  type        = string
  description = "The name of the database"
}

variable "username" {
  type        = string
  description = "The username for the database"
}

variable "rds_port" {
  type        = number
  description = "The port for the RDS instance"
  default     = 5432
}

variable "maintenance_window" {
  type        = string
  description = "The maintenance window for the RDS instance"
  default     = "Mon:04:00-Mon:06:00"
}

variable "backup_window" {
  type        = string
  description = "The backup window for the RDS instance"
  default     = "00:00-03:00"
}

variable "backup_retention_period" {
  type        = number
  description = "The backup retention period for the RDS instance (max 35 days)"
  default     = 35
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Whether to skip the final snapshot when the RDS instance is deleted"
  default     = true
}

variable "parameter_group_parameters" {
  description = "Database parameter group parameters"
  type = list(object({
    name         = string
    value        = string
    apply_method = string
  }))
  default = [
    {
      name         = "auto_explain.log_min_duration"
      value        = 500
      apply_method = "immediate"
    }
  ]
}

variable "analytics_replica" {
  type        = bool
  description = "Whether to create an analytics replica"
}

