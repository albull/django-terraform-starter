output "redis_host1_address" {
  value = aws_elasticache_replication_group.cache.primary_endpoint_address
}

output "module_name" {
  value = local.module_name
}
