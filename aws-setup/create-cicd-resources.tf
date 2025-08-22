# AWS Resources for CI/CD Pipeline
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "webserverdeployment"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = "your-org/webserverdeployment"
  
  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "GitHub repository must be in format 'owner/repo'."
  }
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${var.project_name}-terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name    = "${var.project_name}-terraform-state-lock"
    Purpose = "Terraform state locking"
  }
}

# IAM role for GitHub Actions OIDC
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # GitHub OIDC thumbprints - update if GitHub changes certificates
  # Current thumbprints as of 2024 - monitor for updates
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # GitHub Actions OIDC
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"  # GitHub backup
  ]
}

resource "aws_iam_role" "github_actions" {
  name                 = "${var.project_name}-github-actions-role"
  description          = "IAM role for GitHub Actions CI/CD pipeline with OIDC authentication"
  max_session_duration = 3600

  lifecycle {
    prevent_destroy = true
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })
}

locals {
  cicd_permissions = [
    "ec2:DescribeInstances", "ec2:DescribeInstanceStatus", "ec2:DescribeSecurityGroups",
    "ec2:DescribeSubnets", "ec2:DescribeVpcs", "ec2:RunInstances", "ec2:TerminateInstances", "ec2:CreateTags",
    "elasticloadbalancing:*", "wafv2:*", "cloudwatch:*", "sns:*", "ssm:*",
    "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole", "iam:*RolePolicy", "iam:*InstanceProfile",
    "budgets:*", "ce:GetCostAndUsage", "ce:GetUsageReport"
  ]
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  lifecycle {
    prevent_destroy = true
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = local.cicd_permissions
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = aws_dynamodb_table.terraform_state_lock.arn
      }
    ]
  })
}

# Outputs
output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "setup_commands" {
  description = "Commands to set up GitHub secrets"
  value = <<-EOT
    # Set these as GitHub repository secrets:
    AWS_ROLE_TO_ASSUME: ${aws_iam_role.github_actions.arn}
    TF_STATE_BUCKET: ${aws_s3_bucket.terraform_state.bucket}
    TF_STATE_LOCK_TABLE: ${aws_dynamodb_table.terraform_state_lock.name}
    
    # Optional - Get Infracost API key from https://www.infracost.io/
    INFRACOST_API_KEY: ico-xxxxxxxxxxxxxxxx
  EOT
}