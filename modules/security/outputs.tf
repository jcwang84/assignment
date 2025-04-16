# modules/security/outputs.tf - Placeholder 

output "alb_security_group_id" {
  description = "The ID of the security group for the Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "compute_security_group_id" {
  description = "The ID of the security group for the Compute layer (ECS Tasks / EC2 Instances)."
  value       = aws_security_group.compute.id
}

output "database_security_group_id" {
  description = "The ID of the security group for the Database layer (RDS)."
  value       = aws_security_group.database.id
} 