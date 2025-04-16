# AWS Infrastructure Terraform Project

This project deploys a scalable and highly available AWS infrastructure based on the provided diagram using Terraform.

## Structure

*   `main.tf`: Main configuration invoking modules.
*   `variables.tf`: Input variables.
*   `outputs.tf`: Output values.
*   `backend.tf`: Terraform remote state configuration.
*   `terraform.tfvars`: (Optional, Gitignored) Variable definitions.
*   `modules/`: Contains reusable Terraform modules:
    *   `network/`: VPC, Subnets, IGW, NAT Gateways, Route Tables.
    *   `security/`: Security Groups.
    *   `compute/`: ECS Cluster, Service, ALB / EC2 ASG, ALB.
    *   `database/`: RDS Instance, DB Subnet Group.
*   `app/`: Simple "Hello World!" application (Dockerfile and index.html).
*   `README.md`: This file.
*   `DR_PLAN.md`: Disaster Recovery Plan (to be created).

## Prerequisites

*   AWS Account & configured AWS CLI
*   Terraform installed
*   Git installed
*   Docker installed (if building/pushing the app image locally)

## Deployment

Instructions will be added here.
