data "aws_route53_zone" "zone" {
  count = var.route53_zone_name != "" ? 1 : 0
  name  = var.route53_zone_name
}

resource "aws_route53_record" "airflow" {
  count   = var.route53_zone_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.zone[0].id
  name    = "${aws_lb.airflow.dns_name}"
  type    = "A"

  alias {
    name                   = aws_lb.airflow.dns_name
    zone_id                = aws_lb.airflow.zone_id
    evaluate_target_health = "true"
  }
}

// AWS Record validation

resource "aws_route53_record" "validation" {
  for_each = var.use_https && var.certificate_arn == "" ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone[0].zone_id
}

resource "aws_acm_certificate" "cert" {
  count             = var.use_https && var.certificate_arn == "" ? 1 : 0
  domain_name       = local.dns_record
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_acm_certificate_validation" "cert" {
  count                   = var.use_https && var.certificate_arn == "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
