# modules/database/variables.tf - Placeholder 

variable "database_port" {
  description = "The port the database listens on."
  type        = number
  default     = 3306
}

variable "db_name" {
  description = "The name of the database."
  type        = string
  sensitive   = true
}

variable "db_engine" {
  description = "The database engine to use (e.g., 'postgres', 'mysql')."
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "The database engine version."
  type        = string
  default     = "8.0"
}

variable "db_allocated_storage" {
  description = "The allocated storage for the database."
  type        = number
  sensitive   = true
}

variable "db_password" {
  description = "The master password for the database."
  type        = string
  sensitive   = true
}

variable "db_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the database password."
  type        = string
} 