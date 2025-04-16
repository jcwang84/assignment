# modules/compute/variables.tf - Placeholder 

variable "environment_name" {
  description = "A unique name for the deployment environment. Used for naming/tagging."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where compute resources will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the Application Load Balancer."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "The ID of the security group for the Application Load Balancer."
  type        = string
}

variable "compute_security_group_id" {
  description = "The ID of the security group for the ECS Tasks."
  type        = string
}

variable "app_image_url" {
  description = "URL of the Docker image for the application (e.g., from ECR or Docker Hub)."
  type        = string
  default     = "nginx:alpine" # Default to nginx, assuming Dockerfile build/push is manual or CI/CD
}

variable "app_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 80
}

variable "app_task_cpu" {
  description = "Fargate task CPU units (e.g., 256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "app_task_memory" {
  description = "Fargate task memory in MiB (e.g., 512 = 0.5GB)."
  type        = number
  default     = 512
}

variable "app_desired_count" {
  description = "Desired number of tasks for the ECS service."
  type        = number
  default     = 2 # Default to 2 for basic HA across AZs
}

variable "tags" {
  description = "A map of tags to apply to all compute resources."
  type        = map(string)
  default     = {}
}

# Optional ECR Repo Name
variable "ecr_repository_name" {
  description = "(Optional) Name for the ECR repository to create. If null, no ECR repo is created."
  type        = string
  default     = null
}

variable "db_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the database password. Used to grant task role access."
  type        = string
} 