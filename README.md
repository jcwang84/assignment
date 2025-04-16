# AWS Infrastructure Terraform Project

This project deploys a scalable and highly available AWS infrastructure based on the provided diagram using Terraform.

## Architecture Diagram

A visual representation of the infrastructure created by this project can be found in the [architecture.mmd](./architecture.mmd) file. This file uses Mermaid syntax and can be rendered by various Markdown tools and extensions (including natively on GitHub).

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

2.  **(Prerequisite) Create SSM Parameters:**
    *   Before deploying, you **must** manually create two parameters in AWS Systems Manager Parameter Store in your target AWS region:
        *   **DB Username Parameter:**
            *   **Name:** Choose a name (e.g., `/myapp/dev/db-username`). You will provide this name to Terraform.
            *   **Type:** `String` (or `SecureString`).
            *   **Value:** The desired master username for the RDS database (e.g., `admin`).
        *   **DB Initial Password Parameter:**
            *   **Name:** Choose a name (e.g., `/myapp/dev/db-initial-password`). You will provide this name to Terraform.
            *   **Type:** `SecureString` (using the default or a specific KMS key).
            *   **Value:** The strong initial password for the database master user.

3.  **Set Input Variables:**
    *   The most common way is to create a `terraform.tfvars` file (ensure this file is added to `.gitignore`).
    *   Define required variables:
        *   `environment_name`: A unique name for this specific deployment (e.g., `"prod"`, `"staging"`, `"my-test-1"`).
        *   `aws_region`: The target AWS region (e.g., `"us-east-1"`).
        *   `db_username_ssm_parameter_name`: The **full name** of the SSM parameter you created for the DB username (e.g., `"/myapp/dev/db-username"`).
        *   `initial_db_password_ssm_parameter_name`: The **full name** of the SSM SecureString parameter you created for the initial DB password (e.g., `"/myapp/dev/db-initial-password"`).
    *   You can override other variables defined in `variables.tf` as needed (e.g., `vpc_cidr`, `availability_zones`, `instance_type`, `db_instance_class`).
    *   Example `terraform.tfvars`:
        ```tfvars
        # terraform.tfvars
        environment_name                     = "dev-iteration1"
        aws_region                           = "us-east-1"

        # Database Credentials - SSM Parameter Names
        db_username_ssm_parameter_name         = "/myapp/dev/db-username"
        initial_db_password_ssm_parameter_name = "/myapp/dev/db-initial-password"

        # Optional Overrides
        # availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
        # db_instance_class = "db.t3.small"
        ```

4.  **(Optional) Build & Push Custom Docker Image:**
    *   If you are deploying a custom application instead of the default Nginx:
        *   Ensure your application code uses the AWS SDK to retrieve the database password from the Secrets Manager secret named `${environment_name}-db-password-<random_suffix>` (the exact name is in the secret ARN output). It should use the permissions granted to the ECS Task Role.
        *   Uncomment the `ecr_repository_name` variable in `modules/compute/variables.tf` or set it in `terraform.tfvars`.
        *   Run `terraform init` and `terraform apply` to create the ECR repository first.
        *   Build your Docker image: `docker build -t <repo_url>:latest app/` (replace `<repo_url>` with the `ecr_repository_url` output from Terraform).
        *   Log in to ECR: `aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com`
        *   Push the image: `docker push <repo_url>:latest`
        *   Update the `app_image_url` variable in `terraform.tfvars` or `main.tf` to point to your pushed image URL.

5.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

6.  **Plan Deployment:**
    *   Review the resources Terraform plans to create.
    *   If using `terraform.tfvars`:
        ```bash
        terraform plan
        ```
    *   If passing variables via command line:
        ```bash
        terraform plan -var="environment_name=your-env-name" -var="db_username_ssm_parameter_name=your_db_user" -var="initial_db_password_ssm_parameter_name=your_db_pass"
        ```

7.  **Apply Deployment:**
    *   Apply the changes to create the infrastructure.
    *   If using `terraform.tfvars`:
        ```bash
        terraform apply
        ```
    *   If passing variables via command line:
        ```bash
        terraform apply -var="environment_name=your-env-name" -var="db_username_ssm_parameter_name=your_db_user" -var="initial_db_password_ssm_parameter_name=your_db_pass"
        ```
    *   Confirm by typing `yes` when prompted.
    *   **Note on IAM Roles:** The configuration will attempt to create the standard `ecsTaskExecutionRole`. If this role already exists in your account, the apply step may fail. You might need to import the existing role (`terraform import module.compute.aws_iam_role.ecs_task_execution_role ecsTaskExecutionRole`) or remove the role creation block from `modules/compute/main.tf` if you prefer to rely on the pre-existing role.
    *   **Note on Secret Rotation:** Automatic rotation for the database password in Secrets Manager is configured. The underlying AWS Lambda function (`SecretsManagerRDSMySQLRotationSingleUser`) needs network connectivity (VPC config, Security Group access) to the RDS instance. This network path is **not** configured by this Terraform code and might require manual adjustment in the Lambda console after deployment if rotation fails.

8.  **Test:**
    *   Access the `hello_world_url` output provided by Terraform in your web browser.
You should see the "Hello World!" page.

9.  **Deploying Multiple Environments:**
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
*   Run the destroy command, ensuring you specify the correct variable values (e.g., `environment_name`, SSM parameter names) for the stack you wish to remove:
    *   If using `terraform.tfvars`:
        ```bash
        terraform destroy
        ```
    *   If passing variables via command line:
        ```bash
        terraform destroy -var="environment_name=your-env-name" -var="db_username_ssm_parameter_name=your_db_user" -var="initial_db_password_ssm_parameter_name=your_db_pass"
        ```
*   Confirm by typing `yes`.
