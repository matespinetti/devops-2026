output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the created VPC"

}

output "public_subnets_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "List of public subnets IDs"

}

output "privatge_subnets_ids" {
  value       = [for s in aws_subnet.private : s.id]
  description = "List of public subnets IDs"

}
