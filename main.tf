# AWS Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Store GitHub Token in AWS Secrets Manager
resource "aws_secretsmanager_secret" "github_token" {
  name_prefix = "github-token-${var.environment}-"
  description = "GitHub Personal Access Token for Commitron"
  recovery_window_in_days = 7

  tags = {
    Name = "github-token-${var.environment}"
  }
}

resource "aws_secretsmanager_secret_version" "github_token_value" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token
}

# IAM Role for Lambda with least privilege
resource "aws_iam_role" "lambda_role" {
  name = "github-commit-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "github-commit-lambda-role-${var.environment}"
  }
}

# Custom policy for Lambda to access Secrets Manager
resource "aws_iam_role_policy" "lambda_secrets_policy" {
  name = "github-commit-lambda-secrets-policy-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [aws_secretsmanager_secret.github_token.arn]
      }
    ]
  })
}

# Basic Lambda logging permissions
resource "aws_iam_role_policy" "lambda_logs_policy" {
  name = "github-commit-lambda-logs-policy-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

# Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_package"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "github_commit_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "github-commit-lambda-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 128
  layers          = [var.git_layer_arn]

  environment {
    variables = {
      GITHUB_REPO   = var.github_repo
      FILE_PATH     = var.file_path
      BRANCH        = var.branch
      AWS_SECRET_ID = aws_secretsmanager_secret.github_token.id
      LOG_LEVEL     = var.environment == "prod" ? "INFO" : "DEBUG"
      GIT_PYTHON_REFRESH = "quiet"
    }
  }

  tags = {
    Name = "github-commit-lambda-${var.environment}"
  }
}

# EventBridge rule to trigger Lambda daily
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "github-commit-trigger-${var.environment}"
  description         = "Triggers the GitHub commit Lambda function daily"
  schedule_expression = "rate(1 day)"

  tags = {
    Name = "github-commit-trigger-${var.environment}"
  }
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "GithubCommitLambda"
  arn       = aws_lambda_function.github_commit_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_commit_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}
