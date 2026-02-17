output "db_subnet_group_id" {
  value = aws_db_subnet_group.main.id
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.main.arn
}
