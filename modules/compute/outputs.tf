# modules/compute/outputs.tf - Placeholder 

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "The zone ID of the Application Load Balancer for Route 53 alias records."
  value       = aws_lb.app.zone_id
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository (if created)."
  value       = var.ecr_repository_name != null ? aws_ecr_repository.app[0].repository_url : null
} 