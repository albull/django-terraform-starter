variable "access_accounts" {
  type        = list(string)
  description = "List of AWS accounts that have access to the ECR repository"
}

variable "repo" {
  type        = string
  description = "Repository name"
}