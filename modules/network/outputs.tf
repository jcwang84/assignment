# modules/network/outputs.tf - Placeholder 

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "availability_zones" {
  description = "The Availability Zones used by the module."
  value       = var.availability_zones
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "db_subnet_ids" {
  description = "List of IDs of the database subnets."
  value       = aws_subnet.db[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public Elastic IP addresses assigned to the NAT Gateways."
  value       = aws_eip.nat[*].public_ip
} 