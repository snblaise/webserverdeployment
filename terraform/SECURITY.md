# Security Scanning and Compliance Validation

This document describes the security scanning and compliance validation implemented in our CI/CD pipeline.

## Overview

Our infrastructure deployment pipeline includes comprehensive security scanning to ensure all deployed resources meet security best practices and organizational compliance requirements. The security validation consists of two main components:

1. **Checkov Security Scanning**: Static analysis of Terraform code for security misconfigurations
2. **terraform-compliance Policy Validation**: Policy-as-code validation against organizational requirements

## Security Scanning Tools

### Checkov

Checkov is a static code analysis tool that scans cloud infrastructure configurations for security and compliance misconfigurations.

**Configuration**: `.checkov.yml`
**Purpose**: Validates infrastructure against security best practices
**Scope**: 
- IMDSv2 enforcement (CKV_AWS_79, CKV_AWS_135)
- EBS encryption validation (CKV_AWS_8, CKV_AWS_3)
- Security group restrictions (CKV_AWS_23, CKV_AWS_24, CKV_AWS_25, CKV_AWS_260)
- ALB security configurations (CKV_AWS_91, CKV_AWS_92, CKV_AWS_103)
- Network security (CKV_AWS_88, CKV_AWS_130, CKV_AWS_131)

### terraform-compliance

terraform-compliance enables policy-as-code validation using Gherkin syntax to define compliance rules.

**Configuration**: `compliance-policies/` directory
**Purpose**: Validates infrastructure against organizational policies
**Policies**:
- `imdsv2.feature`: EC2 IMDSv2 requirements
- `ebs_encryption.feature`: EBS encryption requirements
- `security_groups.feature`: Security group least-privilege validation
- `subnet_isolation.feature`: Network isolation requirements
- `waf_protection.feature`: WAF configuration validation

## CI/CD Integration

### Pull Request Validation

When a pull request is created, the pipeline automatically runs:

1. **Terraform Format Check**: Ensures code formatting consistency
2. **Terraform Initialization**: Initializes Terraform with remote backend
3. **Terraform Validation**: Validates Terraform syntax and configuration
4. **Checkov Security Scan**: Scans for security misconfigurations
5. **terraform-compliance Policy Validation**: Validates against organizational policies
6. **Terraform Plan Generation**: Creates deployment plan for review

### Security Scan Failure Handling

**Blocking Behavior**: Security scan failures will block the deployment pipeline
- Failed Checkov checks prevent plan generation
- Policy compliance violations prevent deployment approval
- Detailed error messages guide remediation efforts

**Reporting**: Security scan results are:
- Displayed in GitHub Actions logs
- Commented on pull requests with summary
- Uploaded as artifacts for detailed review
- Integrated into deployment status checks

## Local Development

### Running Security Scans Locally

Use the provided script to run security scans locally before committing:

```bash
cd terraform
./scripts/security-scan.sh
```

This script will:
- Install required tools (checkov, terraform-compliance)
- Run Checkov security scan with project configuration
- Generate Terraform plan for compliance checking
- Run terraform-compliance policy validation
- Provide detailed results and remediation guidance

### Manual Security Scanning

#### Checkov

```bash
# Run Checkov with project configuration
checkov --config-file .checkov.yml -d .

# Run specific checks
checkov -d . --check CKV_AWS_79,CKV_AWS_8

# Generate JSON output for analysis
checkov --config-file .checkov.yml -d . --output json --output-file results.json
```

#### terraform-compliance

```bash
# Generate Terraform plan
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json

# Run compliance validation
terraform-compliance -p compliance-policies -f plan.json
```

## Security Requirements Mapping

### Requirement 7.2: Security Scanning Integration

**Implementation**: Checkov integration in CI/CD pipeline
- Automated security scanning on every pull request
- Configurable security checks via `.checkov.yml`
- Blocking deployment on security violations
- Detailed reporting and remediation guidance

### Requirement 7.3: Policy-as-Code Validation

**Implementation**: terraform-compliance integration
- Organizational policies defined in Gherkin syntax
- Automated policy validation against Terraform plans
- Version-controlled policy definitions
- Extensible policy framework for new requirements

### Requirement 7.4: Security Scan Failure Handling

**Implementation**: Pipeline failure and blocking mechanisms
- Security scan failures block deployment progression
- Detailed error reporting with remediation guidance
- Artifact upload for offline analysis
- Integration with GitHub status checks

## Security Policies

### IMDSv2 Enforcement

**Policy**: `compliance-policies/imdsv2.feature`
**Requirement**: All EC2 instances must use IMDSv2
**Validation**:
- `http_tokens = "required"`
- `http_put_response_hop_limit = 1`

### EBS Encryption

**Policy**: `compliance-policies/ebs_encryption.feature`
**Requirement**: All EBS volumes must be encrypted
**Validation**:
- Root block devices have `encrypted = true`
- KMS key ID specified for encryption

### Security Group Restrictions

**Policy**: `compliance-policies/security_groups.feature`
**Requirement**: Security groups follow least-privilege principles
**Validation**:
- No unrestricted SSH/RDP access
- ALB security groups properly configured
- Minimal required port access

### Network Isolation

**Policy**: `compliance-policies/subnet_isolation.feature`
**Requirement**: Proper network segmentation and isolation
**Validation**:
- EC2 instances in private subnets
- No public IP addresses on EC2 instances
- ALB in public subnets
- NAT Gateway proper placement

### WAF Protection

**Policy**: `compliance-policies/waf_protection.feature`
**Requirement**: WAF protection for web applications
**Validation**:
- WAF Web ACL associated with ALB
- Managed rule groups configured
- Rate limiting rules implemented

## Troubleshooting

### Common Security Violations

1. **IMDSv2 Not Configured**
   ```hcl
   # Add to aws_instance resources
   metadata_options {
     http_tokens                 = "required"
     http_put_response_hop_limit = 1
   }
   ```

2. **EBS Encryption Missing**
   ```hcl
   # Add to aws_instance root_block_device
   root_block_device {
     encrypted = true
     kms_key_id = var.kms_key_id  # Optional
   }
   ```

3. **Security Group Violations**
   ```hcl
   # Remove or restrict overly permissive rules
   ingress {
     from_port   = 80
     to_port     = 80
     protocol    = "tcp"
     cidr_blocks = var.allowed_http_cidrs  # Not ["0.0.0.0/0"]
   }
   ```

### Debugging Security Scans

1. **Review Checkov Results**:
   - Check `checkov_results.json` artifact
   - Review specific check IDs and descriptions
   - Use Checkov documentation for remediation

2. **Debug Policy Compliance**:
   - Review `compliance_plan.json` for Terraform plan details
   - Test policies locally with sample configurations
   - Validate Gherkin syntax in policy files

3. **Local Testing**:
   - Use `./scripts/security-scan.sh` for local validation
   - Test individual policies with terraform-compliance
   - Validate Checkov configuration with sample runs

## Extending Security Validation

### Adding New Checkov Checks

1. Update `.checkov.yml` configuration
2. Add new check IDs to `check:` section
3. Test locally before committing
4. Update documentation

### Creating New Compliance Policies

1. Create new `.feature` file in `compliance-policies/`
2. Use Gherkin syntax for policy definition
3. Test with sample Terraform configurations
4. Update `compliance-policies/README.md`

### Customizing Security Thresholds

1. Modify `.checkov.yml` severity levels
2. Update policy failure conditions
3. Adjust CI/CD pipeline behavior
4. Document changes in security procedures

## Security Contacts

For security-related questions or issues:
- **Security Team**: security@company.com
- **DevOps Team**: devops@company.com
- **Emergency Security Issues**: security-emergency@company.com

## References

- [Checkov Documentation](https://www.checkov.io/1.Welcome/Quick%20Start.html)
- [terraform-compliance Documentation](https://terraform-compliance.com/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Terraform Security Best Practices](https://learn.hashicorp.com/tutorials/terraform/security)