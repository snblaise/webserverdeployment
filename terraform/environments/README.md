# Environment-Specific Configurations

This directory contains environment-specific Terraform variable files for the secure CI/CD pipeline infrastructure.

## Environment Overview

### Test Environment (`test.tfvars`)
- **Purpose**: Automated testing and validation
- **Instance Type**: t3.micro (cost-optimized)
- **Instance Count**: 1 (minimal resources)
- **Monitoring**: Basic CloudWatch metrics
- **Backup**: Optional, 7-day retention
- **Network**: Open access (0.0.0.0/0) for testing
- **Auto-cleanup**: Enabled
- **Deployment**: Automatic on develop branch push

### Staging Environment (`staging.tfvars`)
- **Purpose**: Pre-production validation and user acceptance testing
- **Instance Type**: t3.small (production-like sizing)
- **Instance Count**: 2 (high availability testing)
- **Monitoring**: Enhanced CloudWatch with detailed metrics
- **Backup**: Required, 14-day retention
- **Network**: Restricted to internal networks
- **Deployment**: Manual approval after test success

### Production Environment (`prod.tfvars`)
- **Purpose**: Live customer-facing application
- **Instance Type**: t3.small (production workload)
- **Instance Count**: 2 (high availability)
- **Monitoring**: Enhanced CloudWatch + compliance logging
- **Backup**: Required, 30-day retention
- **Network**: Public access with WAF protection
- **Deployment**: Manual approval after staging success + senior team review

### Preview Environment (`preview.tfvars`)
- **Purpose**: Feature branch testing and development
- **Instance Type**: t3.micro (cost-optimized)
- **Instance Count**: 1 (minimal resources)
- **Monitoring**: Basic metrics only
- **Backup**: None (temporary environments)
- **Network**: Open access for development testing
- **Lifecycle**: Automatic cleanup on PR closure

## Usage

### Local Development
```bash
# Initialize with environment-specific configuration
terraform init -backend-config=backend.hcl

# Plan with specific environment
terraform plan -var-file="environments/test.tfvars"

# Apply with specific environment
terraform apply -var-file="environments/staging.tfvars"
```

### CI/CD Pipeline Usage
The GitHub Actions workflow automatically selects the appropriate configuration:

- **Pull Requests**: Uses `preview.tfvars` with branch-specific workspace
- **Develop Branch**: Uses `test.tfvars` for automated testing
- **Staging Branch**: Uses `staging.tfvars` for pre-production validation
- **Main Branch**: Uses `prod.tfvars` for production deployment

## Configuration Differences

| Setting | Test | Staging | Production | Preview |
|---------|------|---------|------------|---------|
| CIDR Block | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 | 10.10.0.0/16 |
| Instance Type | t3.micro | t3.small | t3.small | t3.micro |
| Instance Count | 1 | 2 | 2 | 1 |
| Detailed Monitoring | false | true | true | false |
| Log Retention | 7 days | 30 days | 90 days | 3 days |
| Backup Retention | 7 days | 14 days | 30 days | 1 day |
| WAF Rate Limit | 5000 | 2000 | 2000 | 10000 |
| Allowed CIDRs | 0.0.0.0/0 | Private only | 0.0.0.0/0 | 0.0.0.0/0 |

## Tagging Strategy

All resources are tagged with a comprehensive set of tags for cost allocation, compliance, and management:

### Standard Tags (All Environments)
- `Project`: Project name
- `Environment`: Environment identifier
- `ManagedBy`: "terraform"
- `Owner`: Resource owner
- `Application`: Application name
- `CostCenter`: Cost allocation
- `CreatedBy`: "terraform"
- `CreatedDate`: Resource creation date
- `Repository`: Source repository name
- `TerraformPath`: Terraform working directory

### Environment-Specific Tags

#### Production
- `CriticalSystem`: "true"
- `Backup`: "required"
- `Monitoring`: "enhanced"
- `Compliance`: "required"

#### Staging
- `ProductionLike`: "true"
- `Backup`: "required"
- `Monitoring`: "enhanced"
- `ApprovalGate`: "required"

#### Test
- `CostOptimized`: "true"
- `AutoCleanup`: "true"
- `Backup`: "optional"
- `Monitoring`: "basic"

#### Preview
- `Temporary`: "true"
- `AutoCleanup`: "true"
- `Backup`: "none"
- `Monitoring`: "basic"
- `CostOptimized`: "true"

## Security Considerations

### Network Isolation
- Each environment uses a separate VPC CIDR block
- Production and staging have restricted access patterns
- Test and preview environments allow broader access for development

### Access Control
- Production requires senior team approval
- Staging requires DevOps team approval
- Test environment has automated deployment
- Preview environments are automatically cleaned up

### Monitoring and Alerting
- Production and staging have enhanced monitoring
- All environments have basic health checks
- Alert routing varies by environment criticality

## Cost Optimization

### Resource Sizing
- Test and preview use t3.micro instances
- Staging and production use t3.small instances
- Instance counts are minimized for non-production environments

### Retention Policies
- Log retention varies by environment importance
- Backup retention is optimized for each environment's needs
- Preview environments have minimal retention

### Auto-cleanup
- Preview environments are automatically destroyed
- Test environments can be scheduled for cleanup
- Staging and production have protection against accidental deletion