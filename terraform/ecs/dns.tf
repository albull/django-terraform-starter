# Request cert from ACM
resource "aws_acm_certificate" "cert" {
  domain_name               = var.zone_name
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-acm-certificate"
  })
}

# DNS zone (specific portion of the DNS namespace)
resource "aws_route53_zone" "app" {
  name = var.zone_name
}

# Post All ACM validations to Route 53
resource "aws_route53_record" "dns" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.app.zone_id
}

# Wait for ACM to validate DNS ownership
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.dns : record.fqdn]
}

# Create a DNS record for the application
resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.app.zone_id
  name    = var.zone_name
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app_subdomains" {
  zone_id = aws_route53_zone.app.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}
