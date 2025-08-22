#!/bin/bash

# Security Scanning Script for Local Development
# This script runs the same security checks that are performed in CI/CD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the terraform directory
if [ ! -f "versions.tf" ]; then
    print_error "This script must be run from the terraform directory"
    exit 1
fi

print_status "Starting security scan for Terraform infrastructure..."

# Check if required tools are installed
print_status "Checking required tools..."

if ! command -v checkov &> /dev/null; then
    print_warning "Checkov not found. Installing..."
    pip install checkov
fi

if ! command -v terraform-compliance &> /dev/null; then
    print_warning "terraform-compliance not found. Installing..."
    pip install terraform-compliance
fi

if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq."
    exit 1
fi

print_success "All required tools are available"

# Run Checkov security scan
print_status "Running Checkov security scan..."

# Run Checkov with both CLI and JSON output
if checkov --config-file .checkov.yml -d . --output cli --output json --output-file checkov_results.json; then
    CHECKOV_FAILED=0
else
    CHECKOV_FAILED=1
fi

# Parse results if JSON file exists
if [ -f "checkov_results.json" ]; then
    FAILED_CHECKS=$(jq -r '.results.failed_checks | length' checkov_results.json 2>/dev/null || echo "0")
    PASSED_CHECKS=$(jq -r '.results.passed_checks | length' checkov_results.json 2>/dev/null || echo "0")
    SKIPPED_CHECKS=$(jq -r '.results.skipped_checks | length' checkov_results.json 2>/dev/null || echo "0")
    
    print_status "Checkov Results: $PASSED_CHECKS passed, $FAILED_CHECKS failed, $SKIPPED_CHECKS skipped"
    
    if [ "$FAILED_CHECKS" -gt "0" ]; then
        print_error "Checkov found $FAILED_CHECKS security violations"
        echo ""
        print_error "Failed security checks:"
        jq -r '.results.failed_checks[] | "❌ \(.check_id): \(.check_name)\n   📁 File: \(.file_path)\n   📝 Severity: \(.severity // "UNKNOWN")\n"' checkov_results.json 2>/dev/null || {
            jq -r '.results.failed_checks[] | "- \(.check_id): \(.file_path) - \(.check_name)"' checkov_results.json
        }
        CHECKOV_FAILED=1
    else
        print_success "Checkov security scan passed ($PASSED_CHECKS checks)"
        CHECKOV_FAILED=0
    fi
else
    print_error "Checkov results file not found - scan may have failed"
    CHECKOV_FAILED=1
fi

# Generate Terraform plan for compliance checking
print_status "Generating Terraform plan for compliance checking..."

# Set default values for local testing
export TF_VAR_env="local-test"
export TF_VAR_project_name="security-test"
export TF_VAR_enable_preview="true"

if terraform plan -out=compliance_plan.tfplan > /dev/null 2>&1; then
    terraform show -json compliance_plan.tfplan > compliance_plan.json
    print_success "Terraform plan generated successfully"
else
    print_error "Failed to generate Terraform plan. Please ensure Terraform is initialized and configured."
    exit 1
fi

# Run terraform-compliance
print_status "Running terraform-compliance policy validation..."

# Set environment variables for compliance checking
export TARGET_ENV="${TF_VAR_env:-local-test}"
export STRICT_MODE="false"
export PRODUCTION_CHECKS="false"

# Count and list policy files
POLICY_COUNT=$(find compliance-policies -name "*.feature" -type f | wc -l)
print_status "Found $POLICY_COUNT compliance policy files:"
find compliance-policies -name "*.feature" -type f | while read -r policy; do
    echo "   - $(basename "$policy")"
done

if [ "$POLICY_COUNT" -eq "0" ]; then
    print_error "No compliance policy files found"
    COMPLIANCE_FAILED=1
else
    # Check if configuration file exists
    if [ -f "compliance-policies/terraform-compliance.yml" ]; then
        print_status "Using terraform-compliance configuration file"
        COMPLIANCE_CMD="terraform-compliance --config compliance-policies/terraform-compliance.yml -f compliance_plan.json --no-ansi"
    else
        print_status "Using default terraform-compliance settings"
        COMPLIANCE_CMD="terraform-compliance -p compliance-policies -f compliance_plan.json --no-ansi"
    fi
    
    # Run terraform-compliance with detailed output
    print_status "Running command: $COMPLIANCE_CMD"
    if eval "$COMPLIANCE_CMD"; then
        print_success "terraform-compliance policy validation passed"
        COMPLIANCE_FAILED=0
    else
        print_error "terraform-compliance policy validation failed"
        echo ""
        print_error "Common policy violations and fixes:"
        echo "1. 🔒 IMDSv2: Add metadata_options block with http_tokens = 'required', http_put_response_hop_limit = 1"
        echo "2. 🔐 EBS Encryption: Add encrypted = true, delete_on_termination = true, volume_type = 'gp3'"
        echo "3. 🛡️  Security Groups: Remove overly permissive rules (0.0.0.0/0), use security group references"
        echo "4. 🌐 Network Isolation: Ensure EC2 in private subnets, ALB in public, VPC endpoints configured"
        echo "5. 🛡️  WAF Protection: Associate WAF Web ACL with ALB, configure logging and metrics"
        echo "6. 🔑 IAM Security: Use name_prefix, avoid wildcard actions on all resources"
        echo "7. 📊 Monitoring: Configure CloudWatch alarms with SNS actions, set log retention"
        echo "8. 🏷️  Tagging: Add required tags (Project, Environment, ManagedBy, Owner)"
        echo "9. ⚖️  Load Balancer: Configure health checks, deletion protection for prod"
        echo "10. 🔧 Patch Management: Configure SSM patch baseline and associations"
        echo ""
        print_status "For detailed troubleshooting, see: compliance-policies/README.md"
        COMPLIANCE_FAILED=1
    fi
fi

# Cleanup temporary files
print_status "Cleaning up temporary files..."
rm -f compliance_plan.tfplan compliance_plan.json

# Summary
echo ""
echo "=========================================="
echo "           SECURITY SCAN SUMMARY"
echo "=========================================="

if [ "$CHECKOV_FAILED" -eq "0" ]; then
    print_success "✅ Checkov Security Scan: PASSED"
else
    print_error "❌ Checkov Security Scan: FAILED"
fi

if [ "$COMPLIANCE_FAILED" -eq "0" ]; then
    print_success "✅ Policy Compliance: PASSED"
else
    print_error "❌ Policy Compliance: FAILED"
fi

echo "=========================================="

# Exit with error if any scan failed
if [ "$CHECKOV_FAILED" -eq "1" ] || [ "$COMPLIANCE_FAILED" -eq "1" ]; then
    print_error "Security scan failed. Please fix the issues above before committing."
    exit 1
else
    print_success "All security scans passed! Your infrastructure is ready for deployment."
    exit 0
fi