output "app_repository_url" {
  description = "URL of the ECR repository for the application"
  value       = aws_ecr_repository.app.repository_url
}

output "module_name" {
  description = "Name of the module"
  value       = local.module_name
}
