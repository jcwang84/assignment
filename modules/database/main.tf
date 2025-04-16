# modules/database/main.tf - Placeholder 

provider "aws" {}

locals {
  # Ensure consistent tagging across resources
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment_name
    }
  )
}

# ------------------------------------------------------------------------------
# DB Subnet Group
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-db-subnet-group"
  })
}

# ------------------------------------------------------------------------------
# Data Source for DB Password Secret
# ------------------------------------------------------------------------------
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = var.db_password_secret_arn
}

# ------------------------------------------------------------------------------
# RDS Instance
# ------------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier           = "${var.environment_name}-db-instance" # Unique identifier for the DB instance
  engine               = var.db_engine
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  storage_type         = "gp2" # General Purpose SSD

  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  password             = data.aws_secretsmanager_secret_version.db_password.secret_string # Get password from Secrets Manager
  port                 = var.database_port # Use the variable here

  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]

  multi_az             = var.db_multi_az
  publicly_accessible  = false

  # Backup & Maintenance
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "04:00-06:00" # Example backup window (UTC)
  maintenance_window      = "sun:10:00-sun:14:00" # Example maintenance window (UTC)
  skip_final_snapshot     = var.db_skip_final_snapshot

  # Recommended settings
  copy_tags_to_snapshot = true
  apply_immediately     = false # Set to true if changes should apply immediately (may cause downtime)
  
  # Performance Insights and Enhanced Monitoring can be enabled here if desired
  # performance_insights_enabled = true
  # monitoring_interval = 60
  # monitoring_role_arn = aws_iam_role.rds_monitoring_role.arn # Requires creating an IAM role

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-db-instance"
  })
}

# Note: You might need an IAM role for enhanced monitoring if you enable it.
# resource "aws_iam_role" "rds_monitoring_role" { ... }
# resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" { ... } 