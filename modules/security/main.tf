# modules/security/main.tf - Placeholder 

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
# Application Load Balancer (ALB) Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.environment_name}-alb-sg"
  description = "Allow HTTP/S traffic to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-alb-sg"
  })
}

# ------------------------------------------------------------------------------
# Compute (ECS Task / EC2 Instance) Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "compute" {
  name        = "${var.environment_name}-compute-sg"
  description = "Allow traffic from ALB and outbound access"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from ALB on application port"
    from_port       = var.application_port
    to_port         = var.application_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow outbound traffic to the internet (e.g., via NAT Gateway for updates/APIs)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-compute-sg"
  })
}

# ------------------------------------------------------------------------------
# Database (RDS) Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "database" {
  name        = "${var.environment_name}-db-sg"
  description = "Allow traffic from Compute SG on DB port"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from Compute SG on DB port"
    from_port       = var.database_port
    to_port         = var.database_port
    protocol        = "tcp"
    security_groups = [aws_security_group.compute.id]
  }

  # Restrict outbound traffic (optional, but good practice)
  # egress {
  #   description = "Allow outbound traffic only within VPC (adjust if needed)"
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = [var.vpc_cidr_block] # Example: Only allow traffic within the VPC
  # }

  # More permissive egress rule (like compute) if DB needs external access (e.g. for extensions)
  egress {
    description = "Allow all outbound traffic (Needed for some DB operations/updates)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-db-sg"
  })
} 