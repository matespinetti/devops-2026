#- 1. Subnet Group for DBs
resource "aws_db_subnet_group" "main" {
  name        = "${local.name}-db-subnet-group"
  description = "DB subnet group for ${local.name}"
  subnet_ids  = local.private_subnet_ids

}

#- 2. ACM Certificate for Domain
resource "aws_acm_certificate" "main" {
  domain_name               = data.aws_route53_zone.main.name
  validation_method         = "DNS"
  subject_alternative_names = ["*.${data.aws_route53_zone.main.name}"]
  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

#- 3. Create the DNS records for ACM validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
  ttl             = 60
  records         = [each.value.record]
}

#- 4. Wait for ACM validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
