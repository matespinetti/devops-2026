#- 1. Subnet Group for RDS DBs
resource "aws_db_subnet_group" "retailstore_rds_main" {
  name        = "${local.name}-rds-subnet-group"
  description = "DB subnet group for ${local.name}"
  subnet_ids  = local.private_subnet_ids

}

#- 2. Subnet Group for ElastiCache
resource "aws_elasticache_subnet_group" "retailstore_elasticache_main" {
  name        = "${local.name}-elasticache-subnet-group"
  description = "ElastiCache subnet group for ${local.name}"
  subnet_ids  = local.private_subnet_ids
}



#- 3. ACM Certificate for Domain
resource "aws_acm_certificate" "main" {
  domain_name               = data.aws_route53_zone.main.name
  validation_method         = "DNS"
  subject_alternative_names = ["*.${data.aws_route53_zone.main.name}"]
  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

#- 4. Create the DNS records for ACM validation
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

#- 5. Wait for ACM validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


#- 6. Iam Policy: Allow access to all retailstore-db-scretes
resource "aws_iam_policy" "retailstore_db_secret_policy" {
  name = "${local.name}-retailstore-db-secret-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:retailstore/*"
      }
    ]
  })

}
