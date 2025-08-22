# Workflow Troubleshooting Guide

## 🔧 Common Issues and Solutions

### 1. Plan Summary Generation Errors

#### Error: "Invalid format '0'" or "Unable to process file command 'output'"

**Cause**: Issues with Terraform plan file parsing or missing dependencies.

**Solution**: 
- ✅ **Fixed in latest workflow**: Enhanced JSON parsing with fallback to text parsing
- ✅ **Automatic error handling**: Defaults to safe values if parsing fails
- ✅ **Robust validation**: Ensures numeric values are always set

**Manual Fix** (if needed):
```bash
# Check if jq is available in the runner
which jq

# Verify plan file exists and is readable
ls -la terraform.tfplan plan.json

# Test plan parsing manually
terraform show -json terraform.tfplan > plan.json
jq '.resource_changes | length' plan.json
```

### 2. Terraform State Lock Issues

#### Error: "Error acquiring the state lock"

**Cause**: Previous Terraform operation didn't complete properly.

**Solution**:
```bash
# Get the lock ID from the error message
# Example: ID: 18626503-1d03-32b3-fdd2-695b029fd444

# Initialize Terraform first
cd terraform
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=infrastructure/webserverdeployment/ENVIRONMENT/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=YOUR_TF_STATE_LOCK_TABLE"

# Force unlock using the lock ID
terraform force-unlock LOCK_ID_FROM_ERROR
```

### 3. Backend Initialization Errors

#### Error: "Backend initialization required"

**Cause**: Terraform backend not properly configured.

**Solution**:
```bash
# Get backend configuration from aws-setup
cd aws-setup
terraform output

# Use the output values to initialize
cd ../terraform
terraform init \
  -backend-config="bucket=OUTPUT_TF_STATE_BUCKET" \
  -backend-config="key=infrastructure/webserverdeployment/ENVIRONMENT/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=OUTPUT_TF_STATE_LOCK_TABLE"
```

### 4. GitHub Secrets Issues

#### Error: "Required secrets not found"

**Cause**: Missing or incorrectly named GitHub repository secrets.

**Solution**:
```bash
# Check current secrets
gh secret list

# Set required secrets (get values from aws-setup terraform output)
gh secret set AWS_ROLE_TO_ASSUME --body "arn:aws:iam::ACCOUNT:role/webserverdeployment-github-actions-role"
gh secret set TF_STATE_BUCKET --body "webserverdeployment-terraform-state-SUFFIX"
gh secret set TF_STATE_LOCK_TABLE --body "webserverdeployment-terraform-state-lock"

# Optional: Infracost API key
gh secret set INFRACOST_API_KEY --body "ico-xxxxxxxxxxxxxxxx"
```

### 5. Security Scan Failures

#### Error: Checkov or terraform-compliance failures

**Cause**: Security policy violations, misconfigurations, or invalid Checkov arguments.

**Common Checkov Errors**:
- `unrecognized arguments: --output-file-name` - Fixed in latest workflow
- `unrecognized arguments: --severity` - Use proper Checkov syntax

**Solution**:
```bash
# Run security scans locally
cd terraform

# Checkov scan (correct syntax)
checkov -d . --output cli --output json --output-file checkov_results.json

# Alternative with specific framework
checkov -f . --framework terraform

# terraform-compliance (if configured)
terraform-compliance -f compliance-policies/ -p plan.json
```

**Common fixes**:
- Enable IMDSv2 on EC2 instances
- Add encryption to storage resources
- Restrict security group rules
- Add resource tagging

### 6. Cost Analysis Issues

#### Error: Infracost failures or missing cost data

**Cause**: Missing Infracost API key or configuration issues.

**Solution**:
```bash
# Check if Infracost is configured
infracost --version

# Test cost analysis locally
infracost breakdown --path terraform/ --format table

# Set API key if missing
gh secret set INFRACOST_API_KEY --body "YOUR_API_KEY"
```

### 7. Resource Import Issues

#### Error: "Resource already exists" during apply

**Cause**: Existing resources not properly imported.

**Solution**: The optimized workflow handles this automatically, but for manual fixes:
```bash
# List existing resources
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId'

# Import existing resource
terraform import aws_instance.main[0] i-1234567890abcdef0

# Run plan again to verify
terraform plan -var-file="environments/test.tfvars"
```

### 8. Environment-Specific Issues

#### Error: "No variable file found for environment"

**Cause**: Missing environment configuration file.

**Solution**:
```bash
# Check available environments
ls terraform/environments/

# Create missing environment file
cp terraform/environments/test.tfvars terraform/environments/YOUR_ENV.tfvars
# Edit the file with appropriate values
```

### 9. Permission Issues

#### Error: AWS permission denied errors

**Cause**: Insufficient IAM permissions for GitHub Actions role.

**Solution**:
```bash
# Check current role permissions
aws sts get-caller-identity

# Verify role trust policy allows GitHub Actions
aws iam get-role --role-name webserverdeployment-github-actions-role

# Update role permissions if needed (in aws-setup directory)
cd aws-setup
terraform plan
terraform apply
```

### 10. Workflow Dispatch Issues

#### Error: Workflow not triggering or inputs not working

**Cause**: Workflow configuration or GitHub interface issues.

**Solution**:
1. **Check workflow file syntax**: Ensure YAML is valid
2. **Verify branch**: Workflow must be on the branch you're running from
3. **Check permissions**: Ensure you have write access to the repository
4. **Manual trigger**: Use GitHub CLI if web interface fails:
   ```bash
   gh workflow run "Infrastructure CI/CD Pipeline (Optimized)" \
     --field environment=test \
     --field force_recreate=false \
     --field skip_tests=false \
     --field dry_run=false
   ```

## 🚨 Emergency Procedures

### Immediate Workflow Stop
```bash
# Cancel running workflow
gh run cancel RUN_ID

# Or cancel all running workflows
gh run list --status in_progress --json databaseId --jq '.[].databaseId' | xargs -I {} gh run cancel {}
```

### Emergency State Recovery
```bash
# Download state backup
aws s3 cp s3://YOUR_TF_STATE_BUCKET/infrastructure/webserverdeployment/ENVIRONMENT/terraform.tfstate ./backup.tfstate

# Restore state if needed
aws s3 cp ./backup.tfstate s3://YOUR_TF_STATE_BUCKET/infrastructure/webserverdeployment/ENVIRONMENT/terraform.tfstate
```

### Force Workflow Reset
```bash
# Reset local Terraform state
cd terraform
rm -rf .terraform/
rm -f terraform.tfplan plan.json

# Reinitialize
terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="key=infrastructure/webserverdeployment/ENVIRONMENT/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=YOUR_TF_STATE_LOCK_TABLE"
```

## 📞 Getting Help

1. **Check workflow logs**: GitHub Actions → Workflow run → Detailed logs
2. **Review artifacts**: Download plan files and test results
3. **Local testing**: Run commands locally to reproduce issues
4. **Dry run mode**: Use `dry_run=true` to test without applying changes

---

*This troubleshooting guide covers the most common issues with the optimized CI/CD pipeline. Keep it updated as new issues are discovered and resolved.*