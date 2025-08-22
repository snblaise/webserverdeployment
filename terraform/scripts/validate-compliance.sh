#!/bin/bash

# Terraform Compliance Validation Script
# This script helps validate terraform-compliance policies locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="test"
TERRAFORM_DIR="."
COMPLIANCE_DIR="compliance-policies"
PLAN_FILE="plan.tfplan"
JSON_FILE="plan.json"
VERBOSE=false
VALIDATE_ONLY=false
FEATURES=""
TAGS=""

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

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate Terraform infrastructure against compliance policies using terraform-compliance.

OPTIONS:
    -e, --environment ENV       Target environment (test, staging, prod, preview) [default: test]
    -d, --terraform-dir DIR     Terraform directory path [default: .]
    -c, --compliance-dir DIR    Compliance policies directory [default: compliance-policies]
    -p, --plan-file FILE        Terraform plan file name [default: plan.tfplan]
    -j, --json-file FILE        JSON plan file name [default: plan.json]
    -f, --features FEATURES     Specific feature files to run (comma-separated)
    -t, --tags TAGS             Specific tags to run (comma-separated)
    -v, --verbose               Enable verbose output
    --validate-only             Only validate policy syntax, don't run compliance checks
    -h, --help                  Show this help message

EXAMPLES:
    # Run all policies for test environment
    $0 -e test

    # Run specific feature for production environment
    $0 -e prod -f imdsv2.feature,security_groups.feature

    # Run policies with specific tags
    $0 -e staging -t security,compliance

    # Validate policy syntax only
    $0 --validate-only

    # Run with verbose output
    $0 -e prod -v

ENVIRONMENT VARIABLES:
    TARGET_ENV                  Override environment setting
    STRICT_MODE                 Enable strict mode (true/false)
    PRODUCTION_CHECKS           Enable production-specific checks (true/false)
    TF_VAR_*                   Terraform variables

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--terraform-dir)
            TERRAFORM_DIR="$2"
            shift 2
            ;;
        -c|--compliance-dir)
            COMPLIANCE_DIR="$2"
            shift 2
            ;;
        -p|--plan-file)
            PLAN_FILE="$2"
            shift 2
            ;;
        -j|--json-file)
            JSON_FILE="$2"
            shift 2
            ;;
        -f|--features)
            FEATURES="$2"
            shift 2
            ;;
        -t|--tags)
            TAGS="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Override environment from environment variable if set
if [[ -n "${TARGET_ENV}" ]]; then
    ENVIRONMENT="${TARGET_ENV}"
fi

# Validate environment
case $ENVIRONMENT in
    test|staging|prod|preview)
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT. Must be one of: test, staging, prod, preview"
        exit 1
        ;;
esac

print_status "Starting terraform-compliance validation"
print_status "Environment: $ENVIRONMENT"
print_status "Terraform directory: $TERRAFORM_DIR"
print_status "Compliance directory: $COMPLIANCE_DIR"

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Check if compliance directory exists
if [[ ! -d "$COMPLIANCE_DIR" ]]; then
    print_error "Compliance directory not found: $COMPLIANCE_DIR"
    exit 1
fi

# Check if terraform-compliance is installed
if ! command -v terraform-compliance &> /dev/null; then
    print_error "terraform-compliance is not installed. Install it with: pip install terraform-compliance"
    exit 1
fi

# Validate policy syntax if requested
if [[ "$VALIDATE_ONLY" == "true" ]]; then
    print_status "Validating policy syntax..."
    if terraform-compliance --validate "$COMPLIANCE_DIR/"; then
        print_success "Policy syntax validation passed"
    else
        print_error "Policy syntax validation failed"
        exit 1
    fi
    exit 0
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi

# Initialize Terraform if needed
if [[ ! -d ".terraform" ]]; then
    print_status "Initializing Terraform..."
    if terraform init -backend=false; then
        print_success "Terraform initialized"
    else
        print_error "Terraform initialization failed"
        exit 1
    fi
fi

# Set environment-specific variables
export TARGET_ENV="$ENVIRONMENT"
export STRICT_MODE="false"
export PRODUCTION_CHECKS="false"

case $ENVIRONMENT in
    prod)
        export STRICT_MODE="true"
        export PRODUCTION_CHECKS="true"
        ;;
    staging)
        export STRICT_MODE="true"
        ;;
esac

# Generate Terraform plan
print_status "Generating Terraform plan..."
PLAN_ARGS=""
if [[ -f "environments/${ENVIRONMENT}.tfvars" ]]; then
    PLAN_ARGS="-var-file=environments/${ENVIRONMENT}.tfvars"
    print_status "Using environment-specific variables: environments/${ENVIRONMENT}.tfvars"
fi

if terraform plan $PLAN_ARGS -out="$PLAN_FILE"; then
    print_success "Terraform plan generated: $PLAN_FILE"
else
    print_error "Terraform plan generation failed"
    exit 1
fi

# Convert plan to JSON
print_status "Converting plan to JSON format..."
if terraform show -json "$PLAN_FILE" > "$JSON_FILE"; then
    print_success "Plan converted to JSON: $JSON_FILE"
else
    print_error "Plan conversion to JSON failed"
    exit 1
fi

# Build terraform-compliance command
COMPLIANCE_CMD="terraform-compliance"

# Add configuration file if it exists
if [[ -f "$COMPLIANCE_DIR/terraform-compliance.yml" ]]; then
    COMPLIANCE_CMD="$COMPLIANCE_CMD --config $COMPLIANCE_DIR/terraform-compliance.yml"
else
    COMPLIANCE_CMD="$COMPLIANCE_CMD -p $COMPLIANCE_DIR"
fi

# Add plan file
COMPLIANCE_CMD="$COMPLIANCE_CMD -f $JSON_FILE"

# Add verbose flag if requested
if [[ "$VERBOSE" == "true" ]]; then
    COMPLIANCE_CMD="$COMPLIANCE_CMD --verbose"
fi

# Add specific features if requested
if [[ -n "$FEATURES" ]]; then
    IFS=',' read -ra FEATURE_ARRAY <<< "$FEATURES"
    for feature in "${FEATURE_ARRAY[@]}"; do
        COMPLIANCE_CMD="$COMPLIANCE_CMD --features $COMPLIANCE_DIR/$feature"
    done
fi

# Add specific tags if requested
if [[ -n "$TAGS" ]]; then
    COMPLIANCE_CMD="$COMPLIANCE_CMD --tags $TAGS"
fi

# Run terraform-compliance
print_status "Running terraform-compliance validation..."
print_status "Command: $COMPLIANCE_CMD"

if eval "$COMPLIANCE_CMD"; then
    print_success "Terraform-compliance validation passed!"
    
    # Clean up temporary files
    print_status "Cleaning up temporary files..."
    rm -f "$PLAN_FILE" "$JSON_FILE"
    
    print_success "Validation completed successfully for environment: $ENVIRONMENT"
else
    print_error "Terraform-compliance validation failed!"
    
    # Keep files for debugging
    print_warning "Keeping plan files for debugging: $PLAN_FILE, $JSON_FILE"
    
    exit 1
fi