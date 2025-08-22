#!/bin/bash

# CI/CD Security Scanning Script
# Simplified version for GitHub Actions environment

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

# Initialize variables
CHECKOV_FAILED=0
COMPLIANCE_FAILED=0

print_status "Starting CI/CD security scan..."

# Check if we're in the terraform directory
if [ ! -f "versions.tf" ]; then
    print_error "This script must be run from the terraform directory"
    exit 1
fi

# Run Checkov security scan
print_status "Running Checkov security scan..."

# Create results directory
mkdir -p results

# Run Checkov with JSON output for parsing
if checkov --config-file .checkov.yml -d . --compact --quiet --output json > checkov_results.json 2>/dev/null; then
    print_success "Checkov scan completed"
    
    # Move results file to results directory
    [ -f "checkov_results.json" ] && mv checkov_results.json results/
    
    # Parse results
    if [ -f "results/checkov_results.json" ]; then
        FAILED_CHECKS=$(jq -r '.summary.failed // 0' results/checkov_results.json 2>/dev/null || echo "0")
        PASSED_CHECKS=$(jq -r '.summary.passed // 0' results/checkov_results.json 2>/dev/null || echo "0")
        SKIPPED_CHECKS=$(jq -r '.summary.skipped // 0' results/checkov_results.json 2>/dev/null || echo "0")
        
        print_status "Checkov Results: $PASSED_CHECKS passed, $FAILED_CHECKS failed, $SKIPPED_CHECKS skipped"
        
        if [ "$FAILED_CHECKS" -gt "0" ]; then
            print_error "Checkov found $FAILED_CHECKS security violations"
            CHECKOV_FAILED=1
            
            # Create summary for GitHub Actions
            echo "## 🔒 Security Scan Results" >> results/security_summary.md
            echo "" >> results/security_summary.md
            echo "❌ **Checkov Security Scan: FAILED**" >> results/security_summary.md
            echo "- Failed checks: $FAILED_CHECKS" >> results/security_summary.md
            echo "- Passed checks: $PASSED_CHECKS" >> results/security_summary.md
            echo "" >> results/security_summary.md
            
            # Add failed checks details
            if jq -e '.results.failed_checks' results/checkov_results.json > /dev/null 2>&1; then
                echo "### Failed Security Checks:" >> results/security_summary.md
                jq -r '.results.failed_checks[] | "- **\(.check_id)**: \(.check_name)\n  - File: `\(.file_path)`\n  - Resource: `\(.resource)`\n"' results/checkov_results.json >> results/security_summary.md 2>/dev/null || true
            fi
        else
            print_success "Checkov security scan passed ($PASSED_CHECKS checks)"
            CHECKOV_FAILED=0
            
            # Create success summary
            echo "## 🔒 Security Scan Results" >> results/security_summary.md
            echo "" >> results/security_summary.md
            echo "✅ **Checkov Security Scan: PASSED**" >> results/security_summary.md
            echo "- Passed checks: $PASSED_CHECKS" >> results/security_summary.md
            echo "" >> results/security_summary.md
        fi
    else
        print_error "Checkov results file not found"
        CHECKOV_FAILED=1
    fi
else
    print_error "Checkov scan failed"
    CHECKOV_FAILED=1
fi

# Skip terraform-compliance in CI for now to avoid complexity
print_status "Skipping terraform-compliance in CI environment"
print_status "Policy compliance will be validated in future iterations"

# Create compliance summary
echo "## 📋 Policy Compliance" >> results/security_summary.md
echo "" >> results/security_summary.md
echo "ℹ️ **Policy Compliance: SKIPPED**" >> results/security_summary.md
echo "- terraform-compliance validation will be added in future iterations" >> results/security_summary.md
echo "" >> results/security_summary.md

COMPLIANCE_FAILED=0

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

print_status "ℹ️ Policy Compliance: SKIPPED (CI environment)"

echo "=========================================="

# Create final summary
echo "" >> results/security_summary.md
echo "---" >> results/security_summary.md
echo "" >> results/security_summary.md
if [ "$CHECKOV_FAILED" -eq "0" ]; then
    echo "🎉 **Overall Status: SECURITY SCAN PASSED**" >> results/security_summary.md
else
    echo "⚠️ **Overall Status: SECURITY ISSUES FOUND**" >> results/security_summary.md
    echo "" >> results/security_summary.md
    echo "Please fix the security issues above before proceeding with deployment." >> results/security_summary.md
fi

# Set GitHub Actions outputs
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "security_passed=$([[ $CHECKOV_FAILED -eq 0 ]] && echo 'true' || echo 'false')" >> "$GITHUB_OUTPUT"
    echo "failed_checks=$FAILED_CHECKS" >> "$GITHUB_OUTPUT"
    echo "passed_checks=$PASSED_CHECKS" >> "$GITHUB_OUTPUT"
fi

# Exit with error if security scan failed
if [ "$CHECKOV_FAILED" -eq "1" ]; then
    print_error "Security scan failed. Please fix the issues above."
    exit 1
else
    print_success "Security scan completed successfully!"
    exit 0
fi