locals {
  app_domain = "live.doiwannaknowthediaryofjane.com"
}

data "aws_route53_zone" "main" {
  name         = "doiwannaknowthediaryofjane.com"
  private_zone = false
}

resource "aws_acm_certificate" "app" {
  domain_name       = local.app_domain
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "app_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.app_cert_validation : r.fqdn]
}

output "app_cert_arn" {
  value = aws_acm_certificate_validation.app.certificate_arn
}

output "app_zone_id" {
  value = data.aws_route53_zone.main.zone_id
}