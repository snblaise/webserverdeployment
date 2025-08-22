# Resource Tagging Strategy

This document outlines the comprehensive tagging strategy implemented for the secure CI/CD pipeline infrastructure.

## Overview

All AWS resources are tagged with a standardized set of tags to enable:
- **Cost Allocation**: Track costs by project, environment, and team
- **Resource Management**: Identify ownership and lifecycle policies
- **Compliance**: Meet organizational and regulatory requirements
- **Automation**: Enable automated operations based on tags
- **Monitoring**: Group resources for monitoring and alerting

## Standard Tags

These tags are applied to all resources across all environments:

| Tag Key | Description | Example Value | Source |
|---------|-------------|---------------|---------|
| `Project` | Project identifier | `secure-cicd-pipeline` | `var.project_name` |
| `Environment` | Environment name | `prod`, `staging`, `test`, `preview` | `var.env` |
| `ManagedBy` | Management tool | `terraform` | Static |
| `Owner` | Resource owner | `DevOps Team` | `var.owner` |
| `Application` | Application name | `Secure CI/CD Pipeline` | `var.application` |
| `CostCenter` | Cost allocation | `devops` | `var.cost_center` |
| `CreatedBy` | Creation method | `terraform` | Static |
| `CreatedDate` | Creation timestamp | `2024-01-15` | `timestamp()` |
| `Repository` | Source repository | `secure-cicd-pipeline` | Static |
| `TerraformPath` | Terraform directory | `/terraform` | `path.cwd` |

## Environment-Specific Tags

Additional tags are automatically applied based on the environment:

### Production Environment
| Tag Key | Value | Purpose |
|---------|-------|---------|
| `CriticalSystem` | `true` | Identifies critical production systems |
| `Backup` | `required` | Indicates backup requirements |
| `Monitoring` | `enhanced` | Specifies monitoring level |
| `Compliance` | `required` | Indicates compliance requirements |

### Staging Environment
| Tag Key | Value | Purpose |
|---------|-------|---------|
| `ProductionLike` | `true` | Indicates production-like configuration |
| `Backup` | `required` | Indicates backup requirements |
| `Monitoring` | `enhanced` | Specifies monitoring level |
| `ApprovalGate` | `required` | Indicates approval requirements |

### Test Environment
| Tag Key | Value | Purpose |
|---------|-------|---------|
| `CostOptimized` | `true` | Indicates cost-optimized configuration |
| `AutoCleanup` | `true` | Enables automated cleanup |
| `Backup` | `optional` | Indicates optional backup |
| `Monitoring` | `basic` | Specifies basic monitoring |

### Preview Environment
| Tag Key | Value | Purpose |
|---------|-------|---------|
| `Temporary` | `true` | Indicates temporary resources |
| `AutoCleanup` | `true` | Enables automated cleanup |
| `Backup` | `none` | No backup required |
| `Monitoring` | `basic` | Specifies basic monitoring |
| `CostOptimized` | `true` | Indicates cost-optimized configuration |

## Resource-Specific Tags

Some resources receive additional tags based on their function:

### EC2 Instances
- `Patch Group`: `{project_name}-{env}` - For SSM patch management
- `Name`: `{project_name}-{env}-instance-{number}` - Instance identifier

### Security Groups
- `Type`: `Public` or `Private` - Network tier classification

### S3 Buckets
- `Purpose`: Specific bucket purpose (e.g., "SSM Patch Management Logs")

### CloudWatch Alarms
- `AlarmType`: Type of alarm (e.g., "HealthCheck", "Performance")

## Custom Tags

Additional tags can be specified using the `additional_tags` variable:

```hcl
additional_tags = {
  "Team"           = "Platform Engineering"
  "BusinessUnit"   = "Technology"
  "ContactEmail"   = "devops@company.com"
  "MaintenanceWindow" = "Sunday-02:00-04:00-UTC"
}
```

## Tag Usage Examples

### Cost Allocation Queries
```bash
# Get costs by environment
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=Environment

# Get costs by project
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY --metrics BlendedCost \
  --group-by Type=TAG,Key=Project
```

### Resource Management
```bash
# Find all production resources
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment,Values=prod

# Find resources requiring backup
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Backup,Values=required

# Find temporary resources for cleanup
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Temporary,Values=true
```

### Automated Operations
```bash
# Stop all test environment instances (cost optimization)
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=test" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text | \
  xargs aws ec2 stop-instances --instance-ids

# Create backup policy for required resources
aws dlm create-lifecycle-policy \
  --execution-role-arn arn:aws:iam::account:role/AWSDataLifecycleManagerDefaultRole \
  --description "Backup policy for required resources" \
  --state ENABLED \
  --policy-details '{
    "ResourceTypes": ["INSTANCE"],
    "TargetTags": [{"Key": "Backup", "Value": "required"}],
    "Schedules": [...]
  }'
```

## Compliance and Governance

### Required Tags Policy
Organizations can enforce tagging policies using AWS Config or Service Control Policies (SCPs):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances",
        "rds:CreateDBInstance",
        "s3:CreateBucket"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:RequestedRegion": "false",
          "aws:RequestTag/Project": "true",
          "aws:RequestTag/Environment": "true",
          "aws:RequestTag/Owner": "true"
        }
      }
    }
  ]
}
```

### Tag Validation
The Terraform configuration includes validation rules for critical tags:

```hcl
variable "env" {
  validation {
    condition     = contains(["test", "staging", "prod", "preview"], var.env)
    error_message = "Environment must be one of: test, staging, prod, preview."
  }
}
```

## Monitoring and Alerting

Tags enable environment-specific monitoring:

### CloudWatch Dashboards
- Separate dashboards per environment using `Environment` tag
- Cost dashboards grouped by `Project` and `CostCenter` tags

### SNS Notifications
- Different notification endpoints based on `Environment` tag
- Critical alerts for resources tagged with `CriticalSystem=true`

### Auto Scaling
- Scaling policies can target instances with specific tags
- Different scaling behaviors for `prod` vs `test` environments

## Best Practices

1. **Consistency**: Use the same tag keys across all resources
2. **Automation**: Apply tags through Terraform, not manually
3. **Validation**: Validate tag values to prevent typos
4. **Documentation**: Keep this document updated with tag changes
5. **Governance**: Implement tag policies for compliance
6. **Cost Management**: Use tags for detailed cost allocation
7. **Lifecycle Management**: Use tags to automate resource lifecycle

## Tag Maintenance

### Regular Reviews
- Monthly review of tag usage and compliance
- Quarterly review of tag strategy effectiveness
- Annual review of tag taxonomy

### Cleanup Procedures
- Identify and remove unused tags
- Standardize tag values across resources
- Update documentation when tags change

### Monitoring
- Set up alerts for untagged resources
- Monitor tag compliance across environments
- Track tag-based cost allocation accuracy