terraform {
  backend "s3" {
    # Replace with your actual S3 bucket name
    bucket = "your-terraform-state-bucket-name" 
    # Replace with your desired state file path/name
    key    = "aws-infra-assignment/terraform.tfstate"
    # Replace with your AWS region 
    region = "us-east-1" 

    # Replace with your actual DynamoDB table name for state locking
    dynamodb_table = "your-terraform-lock-table" 
    encrypt        = true
  }
} 