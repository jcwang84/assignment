# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Global Tags for all resources created by modules
locals {
  global_tags = {
    Project     = "AWS Infra Assignment"
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }
}

# Get current AWS region and account ID for constructing ARNs
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ---------------------------------
# Network Module
# ---------------------------------
module "network" {
  source = "./modules/network"

  environment_name    = var.environment_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs= var.private_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
  tags                = local.global_tags
}

# ---------------------------------
# Secrets Manager for DB Password
# ---------------------------------
resource "aws_secretsmanager_secret" "db_password" {
  name_prefix = "${var.environment_name}-db-password-" # Add prefix for uniqueness
  description = "Password for RDS instance in ${var.environment_name} environment"

  # Auto-rotation can be configured here if needed
  # rotation_lambda_arn = ...
  # rotation_rules {
  #   automatically_after_days = 30
  # }

  tags = merge(local.global_tags, {
    Name = "${var.environment_name}-db-password-secret"
  })
}

# Fetch the initial DB password from SSM Parameter Store
data "aws_ssm_parameter" "initial_db_password" {
  name            = var.initial_db_password_ssm_parameter_name
  with_decryption = true # Required for SecureString parameters
}

# Fetch the DB username from SSM Parameter Store
data "aws_ssm_parameter" "db_username" {
  name            = var.db_username_ssm_parameter_name
  # with_decryption = true # Only needed if storing username as SecureString
}

resource "aws_secretsmanager_secret_version" "db_password_initial" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.initial_db_password
  secret_string = data.aws_ssm_parameter.initial_db_password.value # Use value from SSM

  # Ensures this initial version is only created once and not tracked after
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------
# Secret Rotation Configuration
# ---------------------------------
resource "aws_secretsmanager_secret_rotation" "db_password_rotation" {
  secret_id = aws_secretsmanager_secret.db_password.id
  
  # Use the standard AWS-provided Lambda function for RDS MySQL Single User rotation
  # NOTE: This Lambda must have VPC configuration and security group access 
  #       to reach the RDS instance. This is NOT configured by this Terraform resource.
  #       Manual configuration in the Lambda console might be needed after deployment.
  rotation_lambda_arn = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:lambda:function:SecretsManagerRDSMySQLRotationSingleUser"

  rotation_rules {
    # Rotate every 30 days (adjust as needed)
    automatically_after_days = 30 
  }

  # Set to true if you want the rotation to happen immediately after creation.
  # Recommended to leave as false initially to ensure DB is stable.
  rotate_immediately = false

  depends_on = [
    aws_db_instance.main, # Ensure DB exists before trying to configure rotation
    aws_secretsmanager_secret_version.db_password_initial # Ensure initial version is set
  ]
}

# ---------------------------------
# Security Module
# ---------------------------------
module "security" {
  source = "./modules/security"

  environment_name = var.environment_name
  vpc_id           = module.network.vpc_id
  vpc_cidr_block   = module.network.vpc_cidr_block # Pass VPC CIDR
  database_port    = 3306 # Explicitly set MySQL port
  application_port = 80   # Nginx default port
  tags             = local.global_tags
}

# ---------------------------------
# Database Module
# ---------------------------------
module "database" {
  source = "./modules/database"

  environment_name       = var.environment_name
  db_subnet_ids          = module.network.db_subnet_ids
  db_security_group_id = module.security.database_security_group_id
  
  # Pass required sensitive variables
  db_username            = var.db_username 
  db_username            = data.aws_ssm_parameter.db_username.value # Use value from SSM
  db_password            = var.db_password
  db_password_secret_arn = aws_secretsmanager_secret.db_password.arn # Pass secret ARN
  
  # Pass other config or use defaults
  db_instance_class      = var.db_instance_class
  # db_name                = "myappdb" # Example if you want to override default
  # db_engine              = "mysql" # Default already set in module
  # db_engine_version      = "8.0"   # Default already set in module
  # db_allocated_storage = 20      # Default already set in module
  db_multi_az            = true    # Default already set in module
  db_skip_final_snapshot = true    # Default already set in module

  tags                   = local.global_tags
}

# ---------------------------------
# Compute Module (ECS Fargate)
# ---------------------------------
module "compute" {
  source = "./modules/compute"

  environment_name          = var.environment_name
  vpc_id                    = module.network.vpc_id
  private_subnet_ids        = module.network.private_subnet_ids
  public_subnet_ids         = module.network.public_subnet_ids
  alb_security_group_id     = module.security.alb_security_group_id
  compute_security_group_id = module.security.compute_security_group_id

  # Pass the secret ARN to the compute module so the task role can access it
  db_password_secret_arn    = aws_secretsmanager_secret.db_password.arn

  # app_image_url           = "<your-account-id>.dkr.ecr.<region>.amazonaws.com/${var.environment_name}-app-repo:latest" # Example if using ECR
  app_image_url             = "nginx:alpine" # Using public Nginx for simplicity, assumes manual copy via Dockerfile build
  app_port                  = 80 # Nginx default port
  # app_task_cpu            = 256  # Default
  # app_task_memory         = 512  # Default
  # app_desired_count       = 2    # Default

  # ecr_repository_name = "app-repo" # Uncomment to create an ECR repo

  tags                      = local.global_tags
} 