output "load_balancer_dns_name" {
  value = aws_lb.app.dns_name
}

output "module_name" {
  value = local.module_name
}

output "aws_route53_zone_name" {
  value = aws_route53_zone.app.name
}

output "aws_route53_zone_id" {
  value = aws_route53_zone.app.id
}
