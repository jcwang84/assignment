# modules/compute/main.tf - Placeholder 

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
# (Optional) ECR Repository
# ------------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  count = var.ecr_repository_name != null ? 1 : 0

  name                 = "${var.environment_name}-${var.ecr_repository_name}"
  image_tag_mutability = "MUTABLE" # Or IMMUTABLE for stricter versioning

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-${var.ecr_repository_name}-ecr"
  })
}

# Use the created ECR repo URL if specified, otherwise use the provided image URL
locals {
  app_image = var.ecr_repository_name != null ? aws_ecr_repository.app[0].repository_url : var.app_image_url
}

# ------------------------------------------------------------------------------
# Application Load Balancer (ALB)
# ------------------------------------------------------------------------------
resource "aws_lb" "app" {
  name               = "${var.environment_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false # Set to true for production

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-alb"
  })
}

resource "aws_lb_target_group" "app" {
  name        = "${var.environment_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/" # Path for health check (e.g., /health)
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200" # Expected HTTP status code for healthy
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  # You would add another listener for HTTPS (port 443) 
  # using an ACM certificate if needed for production.
  # resource "aws_lb_listener" "https" { ... }
}

# ------------------------------------------------------------------------------
# ECS Cluster
# ------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.environment_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-ecs-cluster"
  })
}

# ------------------------------------------------------------------------------
# ECS Task Definition
# ------------------------------------------------------------------------------

# Create the ECS Task Execution Role (if it doesn't exist)
# NOTE: If this role already exists in the account, terraform apply will fail.
# See: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole" # Standard name expected by ECS

  # Terraform's "jsonencode" function converts a Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(local.common_tags, {
    Name = "ecsTaskExecutionRole" # Tagging the standard role
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ------------------------------------------------------------------------------
# IAM Role and Policy for ECS Task (to access Secrets Manager)
# ------------------------------------------------------------------------------
resource "aws_iam_role" "app_task_role" {
  name_prefix = "${var.environment_name}-app-task-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-app-task-role"
  })
}

resource "aws_iam_policy" "app_task_secrets_policy" {
  name_prefix = "${var.environment_name}-app-task-secrets-"
  description = "Allow ECS task to read the DB password secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = var.db_password_secret_arn # Grant access ONLY to the specific secret
      },
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-app-task-secrets-policy"
  })
}

resource "aws_iam_role_policy_attachment" "app_task_secrets_attachment" {
  role       = aws_iam_role.app_task_role.name
  policy_arn = aws_iam_policy.app_task_secrets_policy.arn
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.environment_name}-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.app_task_cpu
  memory                   = var.app_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # Reference the created role ARN
  task_role_arn            = aws_iam_role.app_task_role.arn # Assign the task role

  container_definitions = jsonencode([
    {
      name      = "${var.environment_name}-app-container"
      image     = local.app_image # Use the determined image URL
      cpu       = var.app_task_cpu
      memory    = var.app_task_memory
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }
      ]
      # Add environment variables, secrets, logging configuration etc. here if needed
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-app-task-def"
  })
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group for ECS Tasks
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "ecs_app" {
  name              = "/ecs/${var.environment_name}-app"
  retention_in_days = 30 # Adjust retention as needed

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-ecs-logs"
  })
}

# ------------------------------------------------------------------------------
# ECS Service
# ------------------------------------------------------------------------------
resource "aws_ecs_service" "app" {
  name            = "${var.environment_name}-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.compute_security_group_id]
    assign_public_ip = false # Tasks run in private subnets
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.environment_name}-app-container"
    container_port   = var.app_port
  }

  # Ensure ALB is ready before starting the service
  depends_on = [aws_lb_listener.http]

  # Optional: Deployment settings (rolling update, circuit breaker)
  deployment_controller {
    type = "ECS"
  }

  propagate_tags = "SERVICE"

  tags = merge(local.common_tags, {
    Name = "${var.environment_name}-app-service"
  })
} 