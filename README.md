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

1.  **Configure Backend:**
    *   Create an S3 bucket and a DynamoDB table in your desired AWS region for storing Terraform state and managing state locks.
    *   Update `backend.tf` with your actual S3 bucket name (`bucket`) and DynamoDB table name (`dynamodb_table`).

2.  **Set Input Variables:**
    *   The most common way is to create a `terraform.tfvars` file (ensure this file is added to `.gitignore` as it will contain secrets).
    *   Define required variables:
        *   `environment_name`: A unique name for this specific deployment (e.g., `"prod"`, `"staging"`, `"my-test-1"`).
        *   `aws_region`: The target AWS region (e.g., `"us-east-1"`).
        *   `db_username`: The desired master username for the RDS database.
        *   `db_password`: The desired master password for the RDS database (use a strong password).
    *   You can override other variables defined in `variables.tf` as needed (e.g., `vpc_cidr`, `availability_zones`, `instance_type`, `db_instance_class`).
    *   Example `terraform.tfvars`:
        ```tfvars
        # terraform.tfvars
        environment_name = "dev-iteration1"
        aws_region       = "us-east-1"

        # Database Credentials
        db_username = "dbadmin"
        db_password = "ReplaceWithAStrongPassword!"

        # Optional Overrides
        # availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
        # db_instance_class = "db.t3.small"
        ```

3.  **(Optional) Build & Push Custom Docker Image:**
    *   If you are deploying a custom application instead of the default Nginx:
        *   Uncomment the `ecr_repository_name` variable in `modules/compute/variables.tf` or set it in `terraform.tfvars`.
        *   Run `terraform init` and `terraform apply` to create the ECR repository first.
        *   Build your Docker image: `docker build -t <repo_url>:latest app/` (replace `<repo_url>` with the `ecr_repository_url` output from Terraform).
        *   Log in to ECR: `aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com`
        *   Push the image: `docker push <repo_url>:latest`
        *   Update the `app_image_url` variable in `terraform.tfvars` or `main.tf` to point to your pushed image URL.

4.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

5.  **Plan Deployment:**
    *   Review the resources Terraform plans to create.
    *   If using `terraform.tfvars`:
        ```bash
        terraform plan
        ```
    *   If passing variables via command line:
        ```bash
        terraform plan -var="environment_name=your-env-name" -var="db_username=your_db_user" -var="db_password=your_db_pass"
        ```

6.  **Apply Deployment:**
    *   Apply the changes to create the infrastructure.
    *   If using `terraform.tfvars`:
        ```bash
        terraform apply
        ```
    *   If passing variables via command line:
        ```bash
        terraform apply -var="environment_name=your-env-name" -var="db_username=your_db_user" -var="db_password=your_db_pass"
        ```
    *   Confirm by typing `yes` when prompted.

7.  **Test:**
    *   Access the `hello_world_url` output provided by Terraform in your web browser.
You should see the "Hello World!" page.

8.  **Deploying Multiple Environments:**
    *   To deploy another independent instance of the infrastructure (e.g., for staging or another iteration), simply run `terraform plan` and `terraform apply` again, ensuring you provide a **different, unique** value for the `environment_name` variable (either in `terraform.tfvars` or using `-var`). Terraform will create a separate set of resources prefixed with the new environment name.

## Outputs

After a successful `apply`, Terraform will output:

*   `hello_world_url`: The public URL to access the web application.
*   `rds_instance_endpoint`: The connection endpoint for the RDS database.
*   `rds_instance_port`: The port for the RDS database.
*   `vpc_id`: The ID of the created VPC.
*   `ecr_repository_url`: The URL of the ECR repository (if created).

## Destroying Infrastructure

*   **Important:** Destroying the infrastructure is irreversible and will delete all created resources, including the database (unless `skip_final_snapshot` was set to `false`).
*   Run the destroy command, ensuring you specify the correct `environment_name` for the stack you wish to remove:
    *   If using `terraform.tfvars`:
        ```bash
        terraform destroy
        ```
    *   If passing variables via command line:
        ```bash
        terraform destroy -var="environment_name=your-env-name" -var="db_username=your_db_user" -var="db_password=your_db_pass"
        ```
*   Confirm by typing `yes`.
