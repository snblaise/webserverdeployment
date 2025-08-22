# AWS Infrastructure Setup Guide

This guide walks you through setting up the required AWS infrastructure for the CI/CD pipeline.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0 installed
- GitHub CLI (optional, for automated secret setup)

## Step 1: Deploy AWS OIDC Infrastructure

```bash
# Navigate to setup directory
cd aws-setup

# Review and update variables if needed
# Edit create-cicd-resources.tf to match your GitHub repository

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply -auto-approve
```

## Step 2: Configure GitHub Repository Secrets

### Option A: Using GitHub CLI (Recommended)

```bash
# Install GitHub CLI if not available
brew install gh  # macOS
# or
sudo apt install gh  # Ubuntu

# Authenticate
gh auth login --web

# Get values from Terraform output
terraform output

# Set secrets (replace with actual values from output)
gh secret set AWS_ROLE_TO_ASSUME --body "arn:aws:iam::ACCOUNT:role/webserverdeployment-github-actions-role"
gh secret set TF_STATE_BUCKET --body "webserverdeployment-terraform-state-SUFFIX"
gh secret set TF_STATE_LOCK_TABLE --body "webserverdeployment-terraform-state-lock"

# Verify secrets
gh secret list
```

### Option B: Manual Setup via GitHub Web Interface

1. Go to your repository settings: `https://github.com/YOUR_USERNAME/webserverdeployment/settings/secrets/actions`
2. Click "New repository secret"
3. Add each secret with values from `terraform output`

## Step 3: Verify Setup

```bash
# Check that secrets are configured
gh secret list

# Expected output:
# AWS_ROLE_TO_ASSUME
# TF_STATE_BUCKET  
# TF_STATE_LOCK_TABLE
```

## Step 4: Test Optimized Pipeline

Test the pipeline using the GitHub Actions interface:

```bash
# Verify secrets are configured
gh secret list

# Test the optimized workflow
# 1. Go to GitHub Actions in your repository
# 2. Select "Infrastructure CI/CD Pipeline (Optimized)"
# 3. Click "Run workflow"
# 4. Configure test deployment:
#    - Environment: test
#    - Force recreate: false
#    - Skip tests: false
#    - Dry run: true (for initial test)
```

**Expected Results:**
- ✅ Validation and security scanning complete
- ✅ Cost analysis generated
- ✅ Plan created with resource import detection
- ✅ All safety checks passed

## Troubleshooting

### Common Issues

1. **Terraform version mismatch**: Update `required_version` in `create-cicd-resources.tf`
2. **AWS permissions**: Ensure your AWS credentials have IAM, S3, and DynamoDB permissions
3. **GitHub repository mismatch**: Update `github_repository` variable to match your repo

### Cleanup

To remove the AWS infrastructure:

```bash
cd aws-setup
terraform destroy -auto-approve
```

**Warning**: This will delete the S3 bucket and DynamoDB table, removing all Terraform state history.