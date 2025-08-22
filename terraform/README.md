# Secure CI/CD Pipeline Infrastructure

This Terraform configuration deploys a secure, scalable web application infrastructure on AWS with automated patch management.

## Architecture Overview

- **VPC**: Multi-AZ VPC with public and private subnets
- **Compute**: EC2 instances in private subnets behind an Application Load Balancer
- **Security**: WAF, Security Groups, IAM roles with least privilege
- **Monitoring**: CloudWatch alarms, dashboards, and SNS notifications
- **Patch Management**: Automated SSM patch management with compliance monitoring

## Prerequisites

- Terraform >= 1.6
- AWS CLI configured with appropriate credentials
- AWS account with necessary permissions

## Quick Start

### Environment-Specific Deployment

This infrastructure supports multiple environments with pre-configured settings:

1. **Initialize Terraform with backend configuration:**
   ```bash
   terraform init -backend-config=backend.hcl
   ```

2. **Deploy to a specific environment:**
   ```bash
   # Test environment
   terraform plan -var-file="environments/test.tfvars"
   terraform apply -var-file="environments/test.tfvars"
   
   # Staging environment
   terraform plan -var-file="environments/staging.tfvars"
   terraform apply -var-file="environments/staging.tfvars"
   
   # Production environment
   terraform plan -var-file="environments/prod.tfvars"
   terraform apply -var-file="environments/prod.tfvars"
   ```

3. **For custom configurations:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   vim terraform.tfvars
   terraform plan -var-file="terraform.tfvars"
   ```

### Environment Configurations

Pre-configured environments are available in the `environments/` directory:

- **`test.tfvars`**: Cost-optimized for automated testing (t3.micro, single instance)
- **`staging.tfvars`**: Production-like for validation (t3.small, multi-instance)
- **`prod.tfvars`**: Full production configuration (t3.small, enhanced monitoring)
- **`preview.tfvars`**: Minimal for feature branch testing (t3.micro, temporary)

See [environments/README.md](environments/README.md) for detailed configuration differences.

## Configuration Files

### Core Infrastructure
- `versions.tf` - Provider requirements and configuration
- `variables.tf` - Input variables with validation
- `main_vpc.tf` - VPC, subnets, and networking components
- `main_security.tf` - IAM roles, security groups, and WAF
- `main_compute.tf` - EC2 instances and load balancer
- `observability.tf` - CloudWatch monitoring and SNS alerts
- `patching.tf` - SSM patch management configuration
- `outputs.tf` - Output values
- `user_data.sh` - EC2 instance initialization script

### Environment Configurations
- `environments/test.tfvars` - Test environment configuration
- `environments/staging.tfvars` - Staging environment configuration
- `environments/prod.tfvars` - Production environment configuration
- `environments/preview.tfvars` - Preview environment configuration
- `environments/README.md` - Environment configuration documentation

### Documentation
- `TAGGING.md` - Comprehensive resource tagging strategy
- `COST_MONITORING.md` - Cost monitoring and analysis setup
- `terraform.tfvars.example` - Example configuration with all variables

## Key Features

### Security
- EC2 instances in private subnets
- WAF protection with rate limiting and AWS managed rules
- Security groups with minimal required access
- Encrypted EBS volumes
- IMDSv2 enforcement
- VPC endpoints for secure SSM access

### Monitoring
- CloudWatch alarms for EC2 and ALB health
- Custom dashboard for infrastructure metrics
- SNS notifications for alerts
- Centralized logging with CloudWatch Logs

### Patch Management
- Automated weekly patching using SSM Patch Manager
- Patch baseline for Amazon Linux 2023
- Compliance scanning and reporting
- S3 logging for patch operations
- CloudWatch alarms for patch compliance failures

### High Availability
- Multi-AZ deployment
- Auto Scaling Group (configurable instance count)
- Application Load Balancer with health checks
- NAT Gateways in each AZ

## Variables

Key variables you should configure:

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Project name for resource naming | Required |
| `env` | Environment (test/staging/prod/preview) | Required |
| `aws_region` | AWS region | us-east-1 |
| `instance_count` | Number of EC2 instances | 2 |
| `instance_type` | EC2 instance type | t3.micro |
| `sns_email_endpoints` | Email addresses for alerts | [] |
| `patch_schedule` | Cron expression for patching | Sundays 2 AM UTC |

## Outputs

After deployment, you'll get comprehensive information about your infrastructure:

### Application Access
- **Application URL**: Direct HTTP access to your application
- **ALB DNS Name**: Load balancer DNS name
- **Health Check URL**: Application health check endpoint

### Infrastructure Details
- **VPC Information**: VPC ID, CIDR block, subnet IDs
- **Compute Resources**: Instance IDs, private IPs, security group IDs
- **Security**: WAF Web ACL ARN, security group IDs
- **Monitoring**: SNS topic ARN, CloudWatch dashboard URL, alarm names
- **Patch Management**: Patch baseline ID, patch group name, logs bucket

### Environment Information
- **Project Name**: Deployed project identifier
- **Environment**: Current environment (test/staging/prod/preview)
- **AWS Region**: Deployment region
- **Deployment Summary**: Complete resource summary for CI/CD integration

### Example Output
```
application_url = "http://secure-cicd-pipeline-prod-alb-123456789.us-east-1.elb.amazonaws.com"
deployment_summary = {
  "alb_dns_name" = "secure-cicd-pipeline-prod-alb-123456789.us-east-1.elb.amazonaws.com"
  "deployment_time" = "2024-01-15T10:30:00Z"
  "environment" = "prod"
  "instance_count" = 2
  "instance_ids" = ["i-1234567890abcdef0", "i-0987654321fedcba0"]
  "project_name" = "secure-cicd-pipeline"
  "region" = "us-east-1"
  "vpc_id" = "vpc-12345678"
}
```

## Patch Management

The infrastructure includes automated patch management:

- **Schedule**: Weekly patching (configurable via `patch_schedule`)
- **Baseline**: Amazon Linux 2023 with security and critical patches
- **Compliance**: Automated scanning and reporting
- **Logging**: S3 bucket for patch operation logs
- **Monitoring**: CloudWatch alarms for compliance failures

### Patch Groups

EC2 instances are automatically tagged with patch group: `{project_name}-{env}`

### Patch Schedule

Default schedule is Sundays at 2 AM UTC. Customize with:
```hcl
patch_schedule = "cron(0 2 ? * SUN *)"
```

## Monitoring and Alerts

### CloudWatch Alarms

- EC2 status check failures
- High CPU utilization (>80%)
- ALB 5xx errors
- Unhealthy targets
- Patch compliance failures

### SNS Notifications

Configure email endpoints in `terraform.tfvars`:
```hcl
sns_email_endpoints = [
  "admin@example.com",
  "devops@example.com"
]
```

## Security Considerations

- All resources use least privilege IAM policies
- EBS volumes are encrypted
- S3 buckets block public access
- VPC endpoints provide secure AWS service access
- WAF protects against common attacks
- Security groups follow principle of least access

## Resource Tagging

All resources are tagged with a comprehensive tagging strategy for cost allocation, compliance, and management:

### Standard Tags (All Resources)
- `Project`, `Environment`, `Owner`, `Application`
- `ManagedBy`, `CostCenter`, `CreatedBy`, `CreatedDate`
- `Repository`, `TerraformPath`

### Environment-Specific Tags
- **Production**: `CriticalSystem`, `Backup=required`, `Monitoring=enhanced`
- **Staging**: `ProductionLike`, `Backup=required`, `ApprovalGate=required`
- **Test**: `CostOptimized`, `AutoCleanup`, `Backup=optional`
- **Preview**: `Temporary`, `AutoCleanup`, `Backup=none`

See [TAGGING.md](TAGGING.md) for complete tagging strategy documentation.

## Cost Optimization and Monitoring

### Cost Monitoring Features
- **Infracost Integration**: Real-time cost estimates in CI/CD pipeline
- **AWS Budgets**: Monthly budget limits with email alerts (per environment)
- **CloudWatch Billing Alarms**: Threshold-based cost monitoring
- **Cost Anomaly Detection**: Automated detection of unusual spending patterns
- **Cost Threshold Warnings**: PR comments with cost analysis and recommendations

See [COST_MONITORING.md](COST_MONITORING.md) for detailed cost monitoring setup and configuration.

### Resource Sizing by Environment
- **Test/Preview**: t3.micro instances, single instance, minimal monitoring ($15-25/month budget)
- **Staging**: t3.small instances, multi-instance, enhanced monitoring ($75/month budget)
- **Production**: t3.small+ instances, multi-instance, full monitoring ($150/month budget)

### Lifecycle Policies
- S3 patch logs with automatic lifecycle transitions
- Environment-specific CloudWatch log retention (3-90 days)
- Backup retention varies by environment criticality (1-30 days)

### Cost Allocation
- Comprehensive tagging enables detailed cost tracking
- Environment-specific cost centers and allocation
- Automated cleanup for temporary preview environments
- Budget alerts and cost anomaly detection per environment

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

**Note**: This will delete all resources including data. Ensure you have backups if needed.