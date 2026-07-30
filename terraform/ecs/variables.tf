variable "state_bucket" {
  type        = string
  description = "Terraform state bucket"
}

variable "app_cpu" {
  type        = number
  description = "CPU units for the application"
}

variable "app_memory" {
  type        = number
  description = "Memory for the application"
}

variable "service_desired_web_count" {
  type        = number
  description = "Desired number of web services"
}

variable "service_desired_job_count" {
  type        = number
  description = "Desired number of job services"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the application"
}

variable "django_env" {
  type        = string
  description = "Django environment"
}

variable "ecr_repository_url" {
  type        = string
  description = "ECR repository URL"
}

variable "ecr_registry_id" {
  type        = string
  description = "ECR registry ID"
}

variable "ecr_repository_name" {
  type        = string
  description = "ECR repository name"
}

variable "zone_name" {
  type        = string
  description = "Route 53 zone name"
}

variable "public_port" {
  type        = number
  description = "Public port for the application"
  default     = 443
}

variable "app_port" {
  type        = number
  description = "Application port"
  default     = 8000
}

variable "server_threads" {
  type        = number
  description = "Number of server threads"
}

variable "repo" {
  type        = string
  description = "Repository name"
}

variable "jobs_cpu" {
  type        = number
  description = "CPU units for the jobs container"
  default     = 256
}

variable "jobs_memory" {
  type        = number
  description = "Memory for the jobs container"
  default     = 1024
}