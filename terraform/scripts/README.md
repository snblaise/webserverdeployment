# Infrastructure Testing and Validation Scripts

This directory contains comprehensive testing and validation scripts for the secure CI/CD pipeline infrastructure. These scripts validate deployment, security, compliance, and operational aspects of the deployed AWS infrastructure.

## Overview

The testing suite includes the following components:

- **Deployment Validation**: Validates infrastructure components and their configuration
- **Health Checks**: Monitors application and infrastructure health
- **Security Validation**: Validates security configurations and compliance
- **CloudWatch Alarm Testing**: Tests monitoring and alerting functionality
- **Compliance Validation**: Validates infrastructure against policy-as-code rules
- **Comprehensive Test Runner**: Orchestrates all tests with various execution modes

## Scripts

### 1. deployment-validation.sh

Validates deployed infrastructure components and their functionality.

**Usage:**
```bash
./scripts/deployment-validation.sh -e test -p myproject -r us-east-1
```

**Features:**
- VPC and network infrastructure validation
- Application Load Balancer connectivity testing
- WAF configuration verification
- EC2 instance security validation
- Security group rule analysis
- Target group health verification

**Options:**
- `-e, --environment`: Target environment (test/staging/prod/preview)
- `-p, --project-name`: Project name for resource identification
- `-r, --region`: AWS region
- `--skip-destructive`: Skip tests that might affect production traffic
- `-v, --verbose`: Enable verbose output

### 2. health-check.sh

Performs comprehensive health checks on deployed infrastructure.

**Usage:**
```bash
./scripts/health-check.sh -e test -p myproject -r us-east-1
```

**Features:**
- ALB connectivity and response time monitoring
- EC2 instance health verification
- CloudWatch alarm status monitoring
- Target group health tracking
- Continuous monitoring mode
- Multiple output formats (console, JSON, CSV)

**Options:**
- `-c, --continuous`: Run continuous health checks
- `-i, --interval`: Check interval for continuous mode (default: 30s)
- `-n, --max-checks`: Maximum checks in continuous mode (default: 10)
- `-f, --format`: Output format (console/json/csv)
- `-l, --log-file`: Log file path for continuous monitoring

### 3. security-validation.sh

Validates security configurations and compliance of deployed infrastructure.

**Usage:**
```bash
./scripts/security-validation.sh -e test -p myproject -r us-east-1
```

**Features:**
- IMDSv2 configuration validation
- EBS encryption verification
- Security group rule analysis
- Network isolation validation
- WAF configuration checking
- IAM security validation

**Options:**
- `-s, --strict`: Enable strict mode (fail on warnings)
- `-c, --compliance-only`: Only run compliance checks
- `-f, --format`: Output format (console/json/csv)

### 4. cloudwatch-alarm-test.sh

Tests CloudWatch alarms and SNS notifications functionality.

**Usage:**
```bash
./scripts/cloudwatch-alarm-test.sh -e test -p myproject -r us-east-1 -m simulate
```

**Features:**
- Alarm configuration validation
- SNS topic and subscription verification
- Alarm state change simulation
- Stress testing capabilities (use with caution)
- Notification delivery testing

**Test Modes:**
- `safe`: Only check existing alarm states and configurations
- `simulate`: Use CloudWatch alarm state change simulation (recommended)
- `stress`: Generate actual load to trigger alarms (use with caution)

### 5. validate-compliance.sh

Validates Terraform infrastructure against compliance policies using terraform-compliance.

**Usage:**
```bash
./scripts/validate-compliance.sh -e test
```

**Features:**
- Policy-as-code validation
- Environment-specific compliance rules
- Terraform plan analysis
- Policy syntax validation
- Detailed compliance reporting

### 6. security-scan.sh

Runs security scans using Checkov and terraform-compliance for local development.

**Usage:**
```bash
./scripts/security-scan.sh
```

**Features:**
- Checkov security scanning
- terraform-compliance policy validation
- Comprehensive security reporting
- Local development workflow integration

### 7. run-all-tests.sh

Comprehensive test runner that orchestrates all validation scripts.

**Usage:**
```bash
./scripts/run-all-tests.sh -e test -p myproject -r us-east-1
```

**Features:**
- Sequential or parallel test execution
- Comprehensive reporting
- Configurable test categories
- Output logging and archival
- Failure handling options

**Options:**
- `--parallel`: Run tests in parallel where possible
- `--continue-on-failure`: Continue running tests even if some fail
- `--skip-destructive`: Skip tests that might affect production traffic
- `--enable-stress`: Enable stress tests (disabled by default)
- `-o, --output-dir`: Output directory for test results and logs

**Test Categories:**
- `--no-deployment`: Skip deployment validation tests
- `--no-health`: Skip health check tests
- `--no-security`: Skip security validation tests
- `--no-alarms`: Skip CloudWatch alarm tests
- `--no-compliance`: Skip compliance validation tests

## Usage Examples

### Basic Validation

```bash
# Run all tests for test environment
./scripts/run-all-tests.sh -e test -p myproject -r us-east-1

# Run only security and compliance tests
./scripts/run-all-tests.sh -e staging -p myproject -r us-east-1 --no-deployment --no-health --no-alarms

# Run with detailed logging
./scripts/run-all-tests.sh -e test -p myproject -r us-east-1 -v -o ./test-results
```

### Production Validation

```bash
# Conservative production testing
./scripts/run-all-tests.sh -e prod -p myproject -r us-east-1 --skip-destructive

# Security-focused validation
./scripts/security-validation.sh -e prod -p myproject -r us-east-1 -s
```

### Continuous Monitoring

```bash
# Continuous health monitoring
./scripts/health-check.sh -e prod -p myproject -r us-east-1 -c -l health.log

# JSON output for automation
./scripts/health-check.sh -e test -p myproject -r us-east-1 -f json
```

### Development Workflow

```bash
# Local security scanning
./scripts/security-scan.sh

# Compliance validation
./scripts/validate-compliance.sh -e test -v

# Alarm testing with simulation
./scripts/cloudwatch-alarm-test.sh -e test -p myproject -r us-east-1 -m simulate
```

## Integration with CI/CD

These scripts are designed to integrate with the GitHub Actions CI/CD pipeline:

### Pull Request Validation
```yaml
- name: Run Infrastructure Validation
  run: |
    cd terraform
    ./scripts/deployment-validation.sh -e test -p ${{ env.PROJECT_NAME }} -r ${{ env.AWS_REGION }}
```

### Post-Deployment Testing
```yaml
- name: Run Comprehensive Tests
  run: |
    cd terraform
    ./scripts/run-all-tests.sh -e ${{ env.ENVIRONMENT }} -p ${{ env.PROJECT_NAME }} -r ${{ env.AWS_REGION }} --skip-destructive -o ./test-results
```

### Continuous Monitoring
```yaml
- name: Health Check
  run: |
    cd terraform
    ./scripts/health-check.sh -e prod -p ${{ env.PROJECT_NAME }} -r ${{ env.AWS_REGION }} -f json > health-status.json
```

## Output and Logging

### Console Output
All scripts provide colored console output with clear status indicators:
- ✅ Success (green)
- ⚠️ Warning (yellow)
- ❌ Failure (red)
- ℹ️ Information (blue)

### JSON Output
Most scripts support JSON output for automation and integration:
```bash
./scripts/health-check.sh -e test -p myproject -r us-east-1 -f json
```

### CSV Output
Health checks and some validation scripts support CSV output for reporting:
```bash
./scripts/health-check.sh -e test -p myproject -r us-east-1 -f csv
```

### Log Files
When using the comprehensive test runner with output directory:
```bash
./scripts/run-all-tests.sh -e test -p myproject -r us-east-1 -o ./logs
```

Generated files:
- `deployment-validation.log`: Deployment validation results
- `health-check.log`: Health check results
- `security-validation.log`: Security validation results
- `cloudwatch-alarm-test.log`: Alarm test results
- `compliance-validation.log`: Compliance validation results
- `test-summary.json`: Comprehensive test summary

## Prerequisites

### Required Tools
- AWS CLI (configured with appropriate credentials)
- jq (JSON processor)
- curl (for connectivity testing)
- terraform (for compliance validation)

### Optional Tools
- checkov (for security scanning)
- terraform-compliance (for policy validation)
- stress (for stress testing)

### AWS Permissions
The scripts require the following AWS permissions:
- EC2: Describe instances, volumes, VPCs, subnets, security groups
- ELB v2: Describe load balancers, target groups, target health
- WAF v2: Get Web ACL configurations
- CloudWatch: Describe alarms, set alarm state
- SNS: List topics, list subscriptions, publish messages
- SSM: Describe instance information, send commands
- STS: Get caller identity

## Environment Variables

All scripts support standard AWS environment variables:
- `AWS_PROFILE`: AWS profile to use
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `AWS_SESSION_TOKEN`: AWS session token
- `AWS_DEFAULT_REGION`: Default AWS region

## Troubleshooting

### Common Issues

1. **AWS Authentication Errors**
   ```bash
   # Check AWS configuration
   aws sts get-caller-identity
   
   # Set AWS profile
   export AWS_PROFILE=myprofile
   ```

2. **Resource Not Found**
   - Verify project name and environment match deployed resources
   - Check resource tags are properly configured
   - Ensure resources are in the specified region

3. **Permission Denied**
   - Verify AWS credentials have required permissions
   - Check IAM policies for the user/role being used

4. **Timeout Issues**
   - Increase timeout values for slow environments
   - Check network connectivity to AWS services
   - Verify resources are in healthy state

### Debug Mode
Enable verbose output for detailed debugging:
```bash
./scripts/run-all-tests.sh -e test -p myproject -r us-east-1 -v
```

### Test Individual Components
Run individual scripts to isolate issues:
```bash
./scripts/deployment-validation.sh -e test -p myproject -r us-east-1 -v
```

## Best Practices

1. **Environment-Specific Testing**
   - Use conservative settings for production (`--skip-destructive`)
   - Enable stress testing only in test environments
   - Use appropriate timeout values for each environment

2. **Automation Integration**
   - Use JSON output for CI/CD integration
   - Store test results as artifacts
   - Set up notifications for test failures

3. **Continuous Monitoring**
   - Run health checks regularly in production
   - Set up alerting based on test results
   - Archive test logs for historical analysis

4. **Security Validation**
   - Run security validation on every deployment
   - Use strict mode for production environments
   - Regularly update compliance policies

## Contributing

When adding new validation scripts:

1. Follow the existing naming convention
2. Include comprehensive help text and usage examples
3. Support verbose and quiet modes
4. Provide multiple output formats where appropriate
5. Include proper error handling and exit codes
6. Add documentation to this README