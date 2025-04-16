# Disaster Recovery Plan - AWS Infrastructure Terraform Project

This document outlines the disaster recovery (DR) strategy for the AWS infrastructure deployed via the accompanying Terraform project.

## 1. Recovery Objectives

*   **Recovery Time Objective (RTO):** Aim to restore service functionality within **2 hours** of a declared disaster (e.g., AZ failure, critical application failure).
*   **Recovery Point Objective (RPO):** Aim for a maximum data loss of **15 minutes** for the database. This is primarily governed by RDS point-in-time recovery capabilities and snapshot frequency.

## 2. Backup Strategy

*   **Database (RDS MySQL):**
    *   **Automated Backups:** Enabled by default (`backup_retention_period` set in Terraform, default 7 days). Provides point-in-time recovery (PITR) capabilities, typically down to 5-minute granularity.
    *   **Automated Snapshots:** Daily automated snapshots are taken and retained based on the retention period.
    *   **Manual Snapshots:** Recommended before significant changes (e.g., major application upgrades, schema changes). Can be initiated via AWS Console or CLI.
    *   **Cross-Region Snapshots (for Regional DR):** For recovery from a full AWS region failure, automated or manual snapshots should be configured to be copied to a designated secondary DR region (e.g., using AWS Backup or custom scripts). *This requires additional setup beyond the current Terraform configuration.*
*   **Compute (ECS Fargate Tasks):**
    *   The application containers (`nginx` serving `index.html`) are **stateless**. Recovery involves redeploying the containers based on the Docker image (`nginx:alpine` or a custom image in ECR) and the ECS Task Definition managed by Terraform.
    *   No specific EBS volume backups are required for the Fargate tasks themselves.
*   **Code & Configuration (Infrastructure as Code):**
    *   **Git Repository:** The primary source of truth for the application code (`app/`) and Terraform infrastructure code (`*.tf` files). Regular commits and pushes to a remote repository (e.g., GitHub, GitLab) are crucial.
    *   **Terraform State:** Stored remotely and securely in the configured AWS S3 bucket with versioning enabled. State locking is managed via the configured DynamoDB table. The remote backend is critical for recovery and collaboration.

## 3. High Availability (Built-in Resilience)

The architecture incorporates high availability by default to mitigate common failures:

*   **Multiple Availability Zones (AZs):** The VPC is configured with subnets (Public, Private, DB) across 3 distinct AZs as defined in the Terraform variables.
*   **NAT Gateways:** Deployed in each AZ's public subnet, providing redundant outbound internet connectivity for private subnets. Failure of one NAT Gateway affects only resources relying on it in that specific AZ.
*   **RDS Multi-AZ:** The `multi_az = true` setting for the `aws_db_instance` creates a standby replica in a different AZ. RDS automatically handles failover to the standby in case of primary instance failure or AZ disruption, typically within minutes.
*   **ECS Service:** Configured with a `desired_count` (default 2). ECS attempts to place tasks across different AZs (based on the provided private subnets) for application-level resilience. The Application Load Balancer routes traffic only to healthy tasks.
*   **Application Load Balancer (ALB):** Inherently highly available and configured across the public subnets in multiple AZs. It automatically routes traffic away from unhealthy instances or AZs based on health checks.

## 4. Recovery Procedures

**Scenario 1: Application Failure (Single Task/Container)**
*   **Detection:** ECS Service detects task failure via health checks; ALB health checks fail.
*   **Action:** ECS automatically attempts to stop the unhealthy task and launch a replacement task to meet the `desired_count`.
*   **Manual Intervention:** If tasks repeatedly fail, investigate application logs (via CloudWatch Logs), task definition, or underlying image issues. Update task definition/image and redeploy via `terraform apply` or ECS service update.

**Scenario 2: Database Failure/Corruption**
*   **Failure (Primary Instance/AZ):** RDS Multi-AZ automatically fails over to the standby replica in another AZ. The DNS endpoint remains the same. Downtime is typically minimal (minutes).
*   **Corruption/Data Loss:** Restore the database from an automated backup (Point-in-Time Recovery) or a snapshot to a *new* RDS instance. Update the application configuration (if necessary) to point to the new DB endpoint. Test thoroughly before switching traffic.

**Scenario 3: Availability Zone (AZ) Failure**
*   **Impact:** Resources in the failed AZ become unavailable (NAT GW, ECS tasks, potentially the primary RDS instance).
*   **Response:**
    *   **ALB:** Stops sending traffic to tasks in the failed AZ.
    *   **ECS:** Launches replacement tasks in the remaining healthy AZs to meet the `desired_count` (if capacity allows).
    *   **RDS:** Initiates automatic failover to the standby instance if the primary was in the affected AZ.
    *   **NAT Gateway:** Instances in private subnets of the failed AZ lose outbound connectivity. Instances in other AZs continue using their respective NAT Gateways.
*   **Recovery:** Once the AZ recovers, services should automatically rebalance or scale back up. No manual Terraform intervention is usually required unless resources need forced replacement.

**Scenario 4: Region Failure (Advanced DR)**
*   **Prerequisites:** Requires significant additional setup not included in the base Terraform:
    *   Cross-region S3 replication for Terraform state backups.
    *   Cross-region RDS snapshot copying (manual or AWS Backup).
    *   Potentially, active ECR replication to the DR region.
    *   Route 53 health checks and failover routing policies.
*   **Recovery Steps (High Level):**
    1.  Declare disaster for the primary region.
    2.  Deploy the *same* Terraform configuration in the designated secondary DR region (`terraform apply -var="aws_region=<dr-region>" ...`).
    3.  Restore the RDS database from the latest replicated cross-region snapshot in the DR region.
    4.  Update Route 53 (manually or via automated health checks/failover policy) to direct traffic to the ALB endpoint in the DR region.
    5.  Test thoroughly.

## 5. Testing

*   **Backup Restoration:** Periodically test restoring RDS snapshots to a temporary instance to verify backup integrity.
*   **Failover Simulation:** Simulate AZ failures (e.g., by terminating instances/tasks in one AZ, stopping the primary RDS instance via AWS console failover action) to test ALB/ECS/RDS failover mechanisms. Conduct during maintenance windows.
*   **DR Plan Review:** Review and update this DR plan annually or after significant architectural changes. 