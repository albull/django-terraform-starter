variable "state_bucket" {
  type        = string
  description = "The S3 bucket for storing the Terraform state"
}

variable "redis_instance_class" {
  type        = string
  description = "The instance class for the Redis instance"
}

variable "redis_port" {
  type        = number
  description = "The port for the Redis instance"
  default     = 6379
}
