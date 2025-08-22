# GitHub Repository Setup Guide

## Required GitHub Secrets

Configure these secrets in your GitHub repository settings:

### AWS Authentication
```
AWS_ROLE_TO_ASSUME=arn:aws:iam::YOUR-ACCOUNT-ID:role/GitHubActionsRole
```

### Terraform State Management
```
TF_STATE_BUCKET=your-terraform-state-bucket
TF_STATE_LOCK_TABLE=your-terraform-lock-table
```

### Cost Analysis (Optional)
```
INFRACOST_API_KEY=ico-your-infracost-api-key
```

## AWS IAM Role Setup

Create an IAM role for GitHub Actions OIDC:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR-ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR-USERNAME/YOUR-REPO:*"
        }
      }
    }
  ]
}
```

## Quick Setup Commands

```bash
# 1. Create S3 bucket for Terraform state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# 2. Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# 3. Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name your-terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```