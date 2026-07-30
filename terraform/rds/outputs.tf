output "rds_address" {
  value = aws_db_instance.database.address
}

output "rds_port" {
  value = aws_db_instance.database.port
}

output "database_name" {
  value = aws_db_instance.database.db_name
}

output "database_instance_identifier" {
  value = aws_db_instance.database.identifier
}

output "database_instance_resource_id" {
  value = aws_db_instance.database.resource_id
}

output "master_user_name" {
  value = aws_db_instance.database.username
}

output "db_password_ssm_parameter_name" {
  value = aws_ssm_parameter.rds_master_password.name
}

output "db_password_ssm_parameter_arn" {
  value = aws_ssm_parameter.rds_master_password.arn
}

output "rds_security_group_id" {
  value = aws_security_group.database.id
}

output "module_name" {
  value = local.module_name
}