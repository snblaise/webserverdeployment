# Security Scanning and Compliance Validation

This document describes the security scanning and compliance validation implemented in our CI/CD pipeline.

## Overview

Our security scanning approach uses two complementary tools:

1. **Checkov**: Static analysis security scanner for infrastructure as code
2. **terraform-compliance**: Policy-as-code validation framework

Both tools run automatically in the CI/CD pipeline and can be executed locally for development.

## Checkov Security Scanning

### Purpose
Checkov validates our Terraform configuration against security best practices and compliance standards.

### Configuration
Security scanning is configured in `.checkov.yml` with the following key checks:

#### IMDSv2 Requirements (Requirement 3.1)
- `CKV_AWS_79`: Ensure Instance Metadata Service Version 1 is not enabled
- `CKV_AWS_135`: Ensure that EC2 is EBS optimized

#### EBS Encryption Requirements (Requirement 3.2)
- `CKV_AWS_8`: Ensure that EBS volumes are encrypted
- `CKV_AWS_3`: Ensure that EBS volumes are encrypted
- `CKV_AWS_189`: Ensure EBS encryption by default is enabled

#### Security Group Requirements (Requirement 3.4, 3.5)
- `CKV_AWS_23`: No SSH access from 0.0.0.0/0
- `CKV_AWS_24`: No RDP access from 0.0.0.0/0
- `CKV_AWS_260`: No HTTP access from 0.0.0.0/0 (except ALB)

#### Network Security (Requirement 1.1-1.5)
- `CKV_AWS_88`: EC2 instances should not have public IP
- `CKV_AWS_130`: VPC subnets should not assign public IP by default

#### ALB Security (Requirement 2.1)
- `CKV_AWS_103`: Load balancer should use TLS 1.2
- `CKV_AWS_131`: ALB should drop HTTP headers
- `CKV_AWS_150`: Load balancer should have deletion protection

### Running Checkov Locally

```bash
# Install Checkov
pip install checkov

# Run security scan
cd terraform
checkov --config-file .checkov.yml -d .

# Generate JSON report
checkov --config-file .checkov.yml -d . --output json --output-file checkov_results.json
```

### Common Checkov Violations and Fixes

#### IMDSv2 Not Configured (CKV_AWS_79)
**Issue**: EC2 instances not configured to require IMDSv2

**Fix**:
```hcl
resource "aws_instance" "web" {
  # ... other configuration ...
  
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }
}
```

#### EBS Encryption Not Enabled (CKV_AWS_8)
**Issue**: EBS volumes not encrypted

**Fix**:
```hcl
resource "aws_instance" "web" {
  # ... other configuration ...
  
  root_block_device {
    encrypted   = true
    kms_key_id  = var.kms_key_id  # Optional: specify KMS key
    volume_type = "gp3"
    volume_size = 20
  }
}
```

#### Security Group Overly Permissive (CKV_AWS_23, CKV_AWS_260)
**Issue**: Security groups allowing unrestricted access

**Fix**:
```hcl
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs  # Specific CIDRs, not 0.0.0.0/0
  }
}

resource "aws_security_group" "ec2" {
  name_prefix = "${var.project_name}-ec2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # Only from ALB
  }
}
```

## terraform-compliance Policy Validation

### Purpose
terraform-compliance validates our infrastructure against organizational policies using Gherkin syntax.

### Policy Files
Located in `compliance-policies/` directory:

1. **imdsv2.feature**: Validates IMDSv2 configuration
2. **ebs_encryption.feature**: Validates EBS encryption
3. **security_groups.feature**: Validates security group configurations
4. **subnet_isolation.feature**: Validates network isolation
5. **waf_protection.feature**: Validates WAF configuration

### Running terraform-compliance Locally

```bash
# Install terraform-compliance
pip install terraform-compliance

# Generate Terraform plan
cd terraform
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json

# Run policy validation
terraform-compliance -p compliance-policies -f plan.json
```

### Policy Examples

#### IMDSv2 Policy (imdsv2.feature)
```gherkin
Feature: EC2 instances must use IMDSv2
  Scenario: EC2 instances should require IMDSv2
    Given I have aws_instance defined
    When it contains metadata_options
    Then it must contain http_tokens
    And its value must be required
```

#### EBS Encryption Policy (ebs_encryption.feature)
```gherkin
Feature: EBS volumes must be encrypted
  Scenario: EBS root volumes should be encrypted
    Given I have aws_instance defined
    When it contains root_block_device
    Then it must contain encrypted
    And its value must be true
```

## CI/CD Pipeline Integration

### Workflow Steps

1. **Checkov Security Scan**:
   - Installs Checkov
   - Runs security scan with configuration
   - Generates JSON results
   - Fails pipeline on security violations

2. **terraform-compliance Validation**:
   - Installs terraform-compliance
   - Generates Terraform plan in JSON format
   - Validates against all policy files
   - Fails pipeline on policy violations

3. **Results Upload**:
   - Uploads scan results as artifacts
   - Generates security summary report
   - Comments results on pull requests

### Security Scan Failure Handling

When security scans fail:

1. **Pipeline Behavior**:
   - Pipeline fails and blocks deployment
   - Detailed error messages are displayed
   - Artifacts are uploaded for review

2. **Pull Request Comments**:
   - Security status is clearly indicated
   - Failed checks are listed with details
   - Remediation guidance is provided
   - Links to documentation are included

3. **Artifact Upload**:
   - `checkov_results.json`: Detailed Checkov results
   - `compliance_plan.json`: Terraform plan for compliance
   - `security_scan_summary.md`: Human-readable summary

## Local Development Workflow

### Using the Security Scan Script

```bash
# Run comprehensive security scan
cd terraform
./scripts/security-scan.sh
```

This script:
- Checks for required tools (installs if missing)
- Runs Checkov security scan
- Generates Terraform plan
- Runs terraform-compliance validation
- Provides detailed results and remediation guidance

### Pre-commit Integration (Optional)

You can integrate security scanning into your pre-commit hooks:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/bridgecrewio/checkov
    rev: 2.3.228
    hooks:
      - id: checkov
        args: [--config-file, terraform/.checkov.yml, -d, terraform/]
```

## Troubleshooting

### Common Issues

#### Checkov Installation Issues
```bash
# Update pip and install
pip install --upgrade pip
pip install checkov

# Alternative: Use pipx
pipx install checkov
```

#### terraform-compliance Installation Issues
```bash
# Install with specific Python version
python3 -m pip install terraform-compliance

# Alternative: Use conda
conda install -c conda-forge terraform-compliance
```

#### Policy Validation Failures
1. Check Terraform plan generation: `terraform plan -detailed-exitcode`
2. Validate JSON format: `terraform show -json plan.tfplan | jq empty`
3. Test individual policies: `terraform-compliance -p compliance-policies/imdsv2.feature -f plan.json`

### Getting Help

1. **Checkov Documentation**: https://www.checkov.io/
2. **terraform-compliance Documentation**: https://terraform-compliance.com/
3. **AWS Security Best Practices**: https://docs.aws.amazon.com/security/
4. **Team Security Guidelines**: See `SECURITY.md` in this repository

## Security Scan Results Interpretation

### Checkov Results
- **PASSED**: All security checks passed
- **FAILED**: Security violations found (blocks deployment)
- **SKIPPED**: Checks skipped per configuration

### terraform-compliance Results
- **SUCCESS**: All policies passed
- **FAILURE**: Policy violations found (blocks deployment)

### Severity Levels
- **CRITICAL**: Must be fixed immediately
- **HIGH**: Should be fixed before deployment
- **MEDIUM**: Should be addressed in next iteration
- **LOW**: Consider for future improvements

## Continuous Improvement

### Adding New Security Checks

1. **Checkov**: Add check IDs to `.checkov.yml`
2. **terraform-compliance**: Create new `.feature` files in `compliance-policies/`
3. **Testing**: Validate locally before committing
4. **Documentation**: Update this file with new checks

### Policy Updates

When updating security policies:
1. Test changes locally first
2. Consider backward compatibility
3. Update documentation
4. Communicate changes to team
5. Monitor for false positives

This security scanning framework ensures our infrastructure meets security best practices and organizational compliance requirements while providing clear feedback and remediation guidance to developers.