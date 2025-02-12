variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

variable "github_repo" {
  description = "GitHub repository in format username/repo"
  type        = string

  validation {
    condition     = can(regex("^[\\w-]+/[\\w-]+$", var.github_repo))
    error_message = "GitHub repository must be in format username/repo."
  }
}

variable "file_path" {
  description = "Path to the counter file in the repository"
  type        = string
  default     = "counter.txt"

  validation {
    condition     = can(regex("^[\\w-./]+$", var.file_path))
    error_message = "File path can only contain alphanumeric characters, hyphens, underscores, dots, and forward slashes."
  }
}

variable "branch" {
  description = "Git branch to commit to"
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[\\w-./]+$", var.branch))
    error_message = "Branch name can only contain alphanumeric characters, hyphens, underscores, dots, and forward slashes."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "commitron"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

variable "github_token" {
  description = "GitHub Personal Access Token (should be provided via environment variable TF_VAR_github_token)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.github_token) > 0
    error_message = "GitHub token cannot be empty."
  }
}

variable "git_layer_arn" {
  description = "ARN of the Git Lambda Layer"
  type        = string
  default     = "arn:aws:lambda:eu-central-1:553035198032:layer:git-lambda2:8"

  validation {
    condition     = can(regex("^arn:aws:lambda:[\\w-]+:\\d+:layer:[\\w-]+:\\d+$", var.git_layer_arn))
    error_message = "Invalid Lambda layer ARN format."
  }
}
