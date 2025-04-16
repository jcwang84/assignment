# modules/security/variables.tf - Placeholder 

variable "vpc_id" {
  description = "The ID of the VPC where security groups will be created."
  type        = string
}

variable "environment_name" {
  description = "A unique name for the deployment environment (e.g., \"prod\", \"staging\"). Used for tagging."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The primary CIDR block of the VPC (used for allowing internal traffic)."
  type        = string
}

variable "application_port" {
  description = "The port the application container/service listens on (e.g., 80, 8080)."
  type        = number
  default     = 80 # Defaulting to 80 for the Nginx container
}

variable "database_port" {
  description = "The port the database listens on (e.g., 5432 for PostgreSQL, 3306 for MySQL)."
  type        = number
  default     = 3306 # Defaulting to MySQL
}

variable "tags" {
  description = "A map of tags to apply to all security resources."
  type        = map(string)
  default     = {}
} 