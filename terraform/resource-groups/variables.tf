variable "state_bucket" {
  description = "Terraform state bucket"
  type        = string
}

variable "has_ecr" {
  description = "Whether this environment uses the ECR module or not"
  type        = bool
  default     = false
}