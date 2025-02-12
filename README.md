# Commitron

A serverless application that automatically increments a counter in a GitHub repository on a daily basis using AWS Lambda and EventBridge.

## Architecture

- AWS Lambda function that runs on a daily schedule
- AWS EventBridge (CloudWatch Events) for scheduling
- AWS Secrets Manager for secure GitHub token storage
- GitHub repository integration

## Prerequisites

- AWS Account
- Terraform >= 1.0.0
- GitHub Personal Access Token with repo permissions
- Python 3.9+

## Setup

1. Clone this repository
2. Create a GitHub Personal Access Token with repo permissions
3. Configure your AWS credentials
4. Set your GitHub token as an environment variable:
   ```bash
   export TF_VAR_github_token=your_github_token
   # For Windows PowerShell:
   # $env:TF_VAR_github_token="your_github_token"
   ```
5. Create lambda package with dependencies:
   ```bash
   mkdir lambda_package
   pip install gitpython boto3 -t lambda_package/
   copy lambda_function.py lambda_package/
   ```
6. Initialize Terraform:
   ```bash
   terraform init
   ```
7. Create a `terraform.tfvars` file with your variables:
   ```hcl
   environment = "dev"  # or "prod"
   github_repo = "username/repository"
   ```
8. Deploy the infrastructure:
   ```bash
   terraform plan
   terraform apply
   ```

## Features

- Daily automated commits
- Secure token storage
- Environment-based configuration
- CloudWatch Logs integration
- Terraform-managed infrastructure

## Security

- GitHub tokens are stored securely in AWS Secrets Manager
- IAM roles follow the principle of least privilege
- All resources are properly tagged
- Logging and monitoring enabled