# Terraform Compliance Policies

This directory contains terraform-compliance policy files that validate our infrastructure against security and compliance requirements. These policies implement policy-as-code validation to ensure our infrastructure meets security standards and organizational requirements.

## Policy Files

### 1. imdsv2.feature
**Purpose**: Ensures EC2 instances use Instance Metadata Service Version 2 (IMDSv2)
**Requirements**: 3.1 - EC2 instances must require IMDSv2
**Checks**:
- `http_tokens` must be set to `required`
- `http_put_response_hop_limit` must be set to `1`
- `http_endpoint` must be `enabled`
- `instance_metadata_tags` must be `enabled`

### 2. ebs_encryption.feature
**Purpose**: Ensures EBS volumes are encrypted and follow security best practices
**Requirements**: 3.2 - EBS volumes must be encrypted using AWS KMS
**Checks**:
- Root block devices must have `encrypted = true`
- KMS key ID should be specified for encryption when provided
- `delete_on_termination` must be `true` for security
- Volume type should be `gp3` for performance

### 3. security_groups.feature
**Purpose**: Validates security group configurations follow least privilege principles
**Requirements**: 3.4, 3.5 - Security groups with minimal required access
**Checks**:
- No unrestricted SSH access (port 22 from 0.0.0.0/0)
- No unrestricted RDP access (port 3389 from 0.0.0.0/0)
- EC2 security groups should only accept traffic from ALB security groups
- ALB security groups should only allow HTTP from allowed CIDRs (not 0.0.0.0/0)
- VPC endpoint security groups should only allow HTTPS from VPC CIDR
- Security groups should have proper lifecycle management

### 4. subnet_isolation.feature
**Purpose**: Ensures proper network isolation and subnet placement
**Requirements**: 1.1, 1.2, 1.3 - Network infrastructure with proper isolation
**Checks**:
- EC2 instances should not have public IP addresses
- EC2 instances should be in private subnets
- ALB should be internet-facing and in public subnets
- NAT Gateway should be in public subnets
- Private subnets should not auto-assign public IPs
- Public subnets should auto-assign public IPs
- VPC should have DNS hostnames and support enabled
- VPC endpoints should be in private subnets with private DNS enabled

### 5. waf_protection.feature
**Purpose**: Validates WAF configuration and association
**Requirements**: 2.2, 2.3, 2.4 - AWS WAF protection
**Checks**:
- WAF Web ACL associated with ALB
- WAF has managed rule groups configured
- WAF has rate limiting rules
- WAF has CloudWatch metrics and sampled requests enabled
- WAF scope is REGIONAL
- WAF has default allow action
- WAF logging configuration uses CloudWatch

### 6. iam_security.feature
**Purpose**: Validates IAM roles and policies follow security best practices
**Requirements**: 3.3 - IAM roles with least-privilege permissions
**Checks**:
- IAM roles have proper assume role policies with correct version
- EC2 IAM roles only allow EC2 service to assume
- IAM instance profiles reference valid roles
- IAM role policy attachments use AWS managed policies when possible
- Custom IAM policies have proper version and don't allow wildcard actions on all resources
- IAM policies follow proper naming conventions

### 7. monitoring_compliance.feature
**Purpose**: Ensures monitoring and logging are properly configured
**Requirements**: 4.1, 4.2, 4.3, 4.4, 4.5 - Monitoring and alerting
**Checks**:
- CloudWatch alarms have proper configuration and alarm actions
- SNS topics have proper naming
- CloudWatch log groups have retention and proper naming configured
- EC2 instances have detailed monitoring in staging/production environments

### 8. tagging_compliance.feature
**Purpose**: Validates resource tagging follows organizational standards
**Requirements**: 6.1, 6.2, 6.3 - Infrastructure as Code with proper tagging
**Checks**:
- All resources have required tags: Project, Environment, ManagedBy, Owner
- Production resources have CriticalSystem tag set to true
- Preview resources have AutoCleanup tag set to true

### 9. load_balancer_security.feature
**Purpose**: Ensures load balancer security is properly configured
**Requirements**: 2.1 - Application Load Balancer configuration
**Checks**:
- ALB is application type and not internal for public-facing applications
- ALB is deployed across multiple subnets with security groups
- Target groups have health checks enabled with proper configuration
- ALB listeners have proper protocol configuration
- ALB has deletion protection in production
- Target group attachments reference valid instances

### 10. patch_management.feature
**Purpose**: Validates patch management configuration
**Requirements**: 5.1, 5.2, 5.3, 5.4, 5.5 - Automated patch management
**Checks**:
- SSM patch baseline configured for Amazon Linux 2023 with security patches
- SSM patch groups are properly configured
- State Manager associations use proper documents and schedules
- State Manager associations target patch groups
- EC2 instances have patch group tags

## Configuration Files

### terraform-compliance.yml
**Purpose**: Configuration file for terraform-compliance tool
**Features**:
- Output format configuration for CI/CD integration
- Environment-specific settings and variables
- Feature-specific configuration and strict mode settings
- Hooks for custom behavior and reporting
- Integration settings for CI/CD pipelines

## Usage

These policies are automatically executed during the CI/CD pipeline as part of the `terraform-compliance` step. They validate the Terraform plan against our security requirements before deployment.

### Running Locally

To run these policies locally:

```bash
# Generate a Terraform plan in JSON format
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json

# Run terraform-compliance with configuration file
terraform-compliance --config compliance-policies/terraform-compliance.yml -f plan.json

# Or run with specific features directory
terraform-compliance -p compliance-policies -f plan.json

# Run with specific tags (e.g., only security-related policies)
terraform-compliance -p compliance-policies -f plan.json --tags security

# Run in verbose mode for debugging
terraform-compliance -p compliance-policies -f plan.json --verbose
```

### CI/CD Integration

The policies are integrated into the GitHub Actions workflow in `.github/workflows/infra.yml`:

```yaml
- name: Run terraform-compliance
  run: |
    pip install terraform-compliance
    terraform-compliance --config terraform/compliance-policies/terraform-compliance.yml -f plan.json
  env:
    TARGET_ENV: ${{ matrix.environment }}
    STRICT_MODE: ${{ matrix.environment == 'prod' && 'true' || 'false' }}
    PRODUCTION_CHECKS: ${{ matrix.environment == 'prod' && 'true' || 'false' }}
```

### Environment-Specific Validation

The policies support environment-specific validation:

- **Test Environment**: Relaxed validation, focus on basic security requirements
- **Staging Environment**: Strict validation, mirrors production requirements
- **Production Environment**: Strictest validation, all security and compliance checks enabled
- **Preview Environment**: Basic validation, optimized for development workflow

### Policy Syntax

The policies use Gherkin syntax (Given-When-Then) to define compliance rules. For more information on terraform-compliance syntax, see: https://terraform-compliance.com/

#### Example Policy Structure

```gherkin
Feature: Security requirement description
  In order to achieve security goal
  As a security engineer
  I want to ensure specific configuration

  Scenario: Specific security check
    Given I have resource_type defined
    When it contains attribute
    Then it must contain required_attribute
    And its value must be expected_value
```

## Troubleshooting

### Common Policy Violations

1. **IMDSv2 not configured**:
   - Ensure `metadata_options` block is present in `aws_instance` resources
   - Set `http_tokens = "required"`, `http_put_response_hop_limit = 1`, and `http_endpoint = "enabled"`
   - Add `instance_metadata_tags = "enabled"` for enhanced security

2. **EBS encryption not enabled**:
   - Add `encrypted = true` to `root_block_device` blocks
   - Optionally specify `kms_key_id` for custom KMS keys
   - Ensure `delete_on_termination = true` and `volume_type = "gp3"`

3. **Security group violations**:
   - Remove or restrict overly permissive ingress rules (no 0.0.0.0/0 for SSH/RDP/HTTP)
   - Ensure ALB security groups only allow HTTP from allowed CIDRs
   - Ensure EC2 security groups only accept traffic from ALB security groups
   - Add `lifecycle { create_before_destroy = true }` to security groups

4. **Subnet isolation issues**:
   - Verify EC2 instances are placed in private subnets
   - Ensure `associate_public_ip_address = false` for EC2 instances
   - Verify VPC has `enable_dns_hostnames = true` and `enable_dns_support = true`
   - Ensure VPC endpoints are in private subnets with `private_dns_enabled = true`

5. **IAM security violations**:
   - Use `name_prefix` instead of `name` for IAM resources
   - Ensure IAM policies have `Version = "2012-10-17"`
   - Avoid wildcard actions (`*`) on all resources (`*`)
   - Use AWS managed policies when possible

6. **WAF configuration issues**:
   - Ensure WAF Web ACL is associated with ALB
   - Configure `visibility_config` with `cloudwatch_metrics_enabled = true`
   - Set WAF scope to `REGIONAL` for ALB association
   - Configure WAF logging with CloudWatch log group

7. **Monitoring compliance issues**:
   - Configure CloudWatch alarms with proper `alarm_actions` referencing SNS topics
   - Set `retention_in_days` for CloudWatch log groups
   - Enable `monitoring = true` for EC2 instances in staging/production

8. **Tagging compliance violations**:
   - Ensure all resources have required tags: `Project`, `Environment`, `ManagedBy`, `Owner`
   - Add `CriticalSystem = "true"` for production resources
   - Add `AutoCleanup = "true"` for preview resources

9. **Load balancer security issues**:
   - Set `load_balancer_type = "application"` for ALBs
   - Configure `enable_deletion_protection = true` for production ALBs
   - Ensure target groups have `health_check { enabled = true }`
   - Deploy ALB across multiple subnets

10. **Patch management violations**:
    - Configure SSM patch baseline for `AMAZON_LINUX_2023`
    - Include `Security` in patch classification values
    - Add `Patch Group` tags to EC2 instances
    - Configure State Manager associations with `AWS-RunPatchBaseline`

### Policy Development Guidelines

When developing or updating policies:

1. **Test Locally**: Always test policy changes locally before committing
2. **Gherkin Syntax**: Ensure policy syntax follows valid Gherkin format
3. **Environment Awareness**: Consider environment-specific requirements (test vs. production)
4. **Backward Compatibility**: Ensure changes don't break existing infrastructure
5. **Documentation**: Update this README when adding new policies
6. **Validation**: Use `terraform-compliance --validate` to check policy syntax

### Debugging Policy Failures

To debug policy failures:

```bash
# Run with verbose output
terraform-compliance -p compliance-policies -f plan.json --verbose

# Run specific feature only
terraform-compliance -p compliance-policies -f plan.json --features imdsv2.feature

# Generate detailed report
terraform-compliance -p compliance-policies -f plan.json --junit-xml compliance-report.xml

# Check policy syntax
terraform-compliance --validate compliance-policies/
```

### Environment-Specific Troubleshooting

**Test Environment**:
- Relaxed validation, focus on basic security
- Encryption and monitoring requirements are optional
- Cost optimization takes priority

**Staging Environment**:
- Strict validation enabled
- All security requirements enforced
- Mirrors production configuration

**Production Environment**:
- Strictest validation
- All compliance checks enabled
- Deletion protection required
- Enhanced monitoring mandatory

**Preview Environment**:
- Basic validation only
- Auto-cleanup tags required
- Cost-optimized configuration

### Updating Policies

When updating policies:

1. **Create Feature Branch**: Create a new branch for policy changes
2. **Test Locally**: Run terraform-compliance locally with test plans
3. **Update Documentation**: Update this README with new policy descriptions
4. **Environment Testing**: Test policies against all environment configurations
5. **Peer Review**: Have security team review policy changes
6. **Gradual Rollout**: Deploy to test environment first, then staging, then production
7. **Monitor Impact**: Monitor CI/CD pipeline for policy violation trends

### Custom Policy Development

To create custom policies:

1. **Identify Requirement**: Define the security or compliance requirement
2. **Write Gherkin Scenario**: Create scenario using Given-When-Then syntax
3. **Test Against Plan**: Validate policy against actual Terraform plans
4. **Add Configuration**: Update `terraform-compliance.yml` if needed
5. **Document Policy**: Add policy description to this README
6. **Integration Test**: Test in CI/CD pipeline