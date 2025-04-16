output "hello_world_url" {
  description = "The public URL of the deployed Hello World service."
  value       = "http://${module.compute.alb_dns_name}" # Constructing HTTP URL
}

output "rds_instance_endpoint" {
  description = "The connection endpoint for the RDS database instance."
  value       = module.database.db_instance_endpoint
  sensitive   = true # Endpoint might be considered sensitive
}

output "rds_instance_port" {
  description = "The port for the RDS database instance."
  value       = module.database.db_instance_port
}

output "vpc_id" {
  description = "The ID of the deployed VPC."
  value       = module.network.vpc_id
}

# Add other outputs as needed, e.g., ECR repo URL
output "ecr_repository_url" {
  description = "The URL of the ECR repository (if created)."
  value       = module.compute.ecr_repository_url
} 