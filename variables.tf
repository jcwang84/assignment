variable "aws_region" {
  description = "AWS region for deployment."
  type        = string
  default     = "us-east-1"
}

variable "environment_name" {
  description = "A unique name for this deployment instance (e.g., \"prod\", \"staging\", \"iteration1\"). Used to prefix resource names."
  type        = string
  # No default, should be provided explicitly for each deployment
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones to use (requires 3)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) == 3
    error_message = "This configuration requires exactly 3 Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 3
    error_message = "Requires exactly 3 public subnet CIDR blocks, one for each AZ."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Requires exactly 3 private subnet CIDR blocks, one for each AZ."
  }
}

variable "db_subnet_cidrs" {
  description = "List of CIDR blocks for database subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  validation {
    condition     = length(var.db_subnet_cidrs) == 3
    error_message = "Requires exactly 3 DB subnet CIDR blocks, one for each AZ."
  }
}

variable "instance_type" {
  description = "(Optional) EC2/ECS instance type."
  type        = string
  default     = "t3.micro" # Example default, adjust if needed
}

variable "db_instance_class" {
  description = "(Optional) RDS instance class."
  type        = string
  default     = "db.t3.micro" # Example default, adjust if needed
}

variable "db_username_ssm_parameter_name" {
  description = "The name of the SSM Parameter Store parameter holding the DB username."
  type        = string
  # No default, must be provided (e.g., in terraform.tfvars)
}

variable "db_password" {
  description = "Database master password."
  type        = string
  sensitive   = true
  # No default, should be provided via tfvars or environment variables
}

variable "initial_db_password" {
  description = "The initial password to set for the database master user in Secrets Manager. Treat this as sensitive and set via .tfvars or environment variable."
  type        = string
  sensitive   = true # Although setting the initial value, treat the input as sensitive
  # No default, must be provided
}

variable "initial_db_password_ssm_parameter_name" {
  description = "The name of the SSM Parameter Store SecureString parameter holding the initial DB password."
  type        = string
  sensitive   = true # Although setting the initial value, treat the input as sensitive
  # No default, must be provided
} 