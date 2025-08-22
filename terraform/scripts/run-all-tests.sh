#!/bin/bash

# Comprehensive Test Runner
# Orchestrates all validation and health check scripts
# Requirements: 4.1, 4.2, 4.3

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="test"
PROJECT_NAME=""
AWS_REGION=""
VERBOSE=false
SKIP_DESTRUCTIVE=false
SKIP_STRESS=true
OUTPUT_DIR=""
PARALLEL=false
CONTINUE_ON_FAILURE=false

# Test categories
RUN_DEPLOYMENT=true
RUN_HEALTH=true
RUN_SECURITY=true
RUN_ALARMS=true
RUN_COMPLIANCE=true

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

print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run comprehensive validation and health checks on deployed AWS infrastructure.

OPTIONS:
    -e, --environment ENV       Target environment (test, staging, prod, preview) [required]
    -p, --project-name NAME     Project name for resource identification [required]
    -r, --region REGION         AWS region [required]
    -o, --output-dir DIR        Output directory for test results and logs
    --skip-destructive          Skip tests that might affect production traffic
    --skip-stress               Skip stress tests (default: true)
    --enable-stress             Enable stress tests (use with caution)
    --parallel                  Run tests in parallel where possible
    --continue-on-failure       Continue running tests even if some fail
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

TEST CATEGORIES (can be disabled individually):
    --no-deployment             Skip deployment validation tests
    --no-health                 Skip health check tests
    --no-security               Skip security validation tests
    --no-alarms                 Skip CloudWatch alarm tests
    --no-compliance             Skip compliance validation tests

EXAMPLES:
    # Run all tests for test environment
    $0 -e test -p myproject -r us-east-1

    # Run production tests with conservative settings
    $0 -e prod -p myproject -r us-east-1 --skip-destructive -o ./test-results

    # Run only security and compliance tests
    $0 -e staging -p myproject -r us-east-1 --no-deployment --no-health --no-alarms

    # Run tests in parallel with detailed logging
    $0 -e test -p myproject -r us-east-1 --parallel -v -o ./logs

ENVIRONMENT VARIABLES:
    AWS_PROFILE                 AWS profile to use
    AWS_ACCESS_KEY_ID          AWS access key
    AWS_SECRET_ACCESS_KEY      AWS secret key
    AWS_SESSION_TOKEN          AWS session token

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --skip-destructive)
            SKIP_DESTRUCTIVE=true
            shift
            ;;
        --skip-stress)
            SKIP_STRESS=true
            shift
            ;;
        --enable-stress)
            SKIP_STRESS=false
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --continue-on-failure)
            CONTINUE_ON_FAILURE=true
            shift
            ;;
        --no-deployment)
            RUN_DEPLOYMENT=false
            shift
            ;;
        --no-health)
            RUN_HEALTH=false
            shift
            ;;
        --no-security)
            RUN_SECURITY=false
            shift
            ;;
        --no-alarms)
            RUN_ALARMS=false
            shift
            ;;
        --no-compliance)
            RUN_COMPLIANCE=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
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

# Validate required parameters
if [[ -z "$ENVIRONMENT" || -z "$PROJECT_NAME" || -z "$AWS_REGION" ]]; then
    print_error "Missing required parameters. Use -h for help."
    exit 1
fi

# Create output directory if specified
if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_DIR=$(realpath "$OUTPUT_DIR")
    print_status "Test results will be saved to: $OUTPUT_DIR"
fi

# Check if we're in the terraform directory
if [[ ! -f "versions.tf" ]]; then
    print_error "This script must be run from the terraform directory"
    exit 1
fi

# Check required tools
for tool in aws jq; do
    if ! command -v $tool &> /dev/null; then
        print_error "$tool is required but not installed"
        exit 1
    fi
done

# Test AWS connectivity
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS authentication failed. Please configure AWS credentials."
    exit 1
fi

# Initialize test tracking
TEST_RESULTS=()
FAILED_TESTS=0
TOTAL_TESTS=0
START_TIME=$(date +%s)

# Function to run a test script
run_test() {
    local test_name="$1"
    local script_path="$2"
    local script_args="$3"
    local log_file="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    print_header "Running $test_name..."
    
    local test_start=$(date +%s)
    local exit_code=0
    
    # Build command
    local cmd="$script_path $script_args"
    
    if [[ "$VERBOSE" == "true" ]]; then
        cmd="$cmd -v"
    fi
    
    # Validate script path for security
    if [[ ! "$script_path" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        print_error "Invalid script path: $script_path"
        return 1
    fi
    
    # Run the test
    if [[ -n "$log_file" ]]; then
        if "$script_path" $script_args > "$log_file" 2>&1; then
            exit_code=0
        else
            exit_code=$?
        fi
        
        # Show last few lines of output
        if [[ "$VERBOSE" == "true" ]]; then
            echo "--- Last 10 lines of output ---"
            tail -10 "$log_file"
            echo "--- End of output ---"
        fi
    else
        if "$script_path" $script_args; then
            exit_code=0
        else
            exit_code=$?
        fi
    fi
    
    local test_end=$(date +%s)
    local test_duration=$((test_end - test_start))
    
    # Record result
    if [[ $exit_code -eq 0 ]]; then
        print_success "✅ $test_name completed successfully (${test_duration}s)"
        TEST_RESULTS+=("✅ $test_name: PASSED (${test_duration}s)")
    else
        print_error "❌ $test_name failed with exit code $exit_code (${test_duration}s)"
        TEST_RESULTS+=("❌ $test_name: FAILED (exit code: $exit_code, duration: ${test_duration}s)")
        FAILED_TESTS=$((FAILED_TESTS + 1))
        
        if [[ "$CONTINUE_ON_FAILURE" != "true" ]]; then
            print_error "Stopping test execution due to failure. Use --continue-on-failure to continue."
            return $exit_code
        fi
    fi
    
    return $exit_code
}

# Function to run tests in parallel
run_parallel_tests() {
    local pids=()
    local test_names=()
    local log_files=()
    
    # Start all tests
    for test_config in "$@"; do
        IFS='|' read -r test_name script_path script_args log_file <<< "$test_config"
        
        if [[ -n "$log_file" ]]; then
            log_files+=("$log_file")
        else
            log_files+=("")
        fi
        
        test_names+=("$test_name")
        
        # Run test in background
        (run_test "$test_name" "$script_path" "$script_args" "$log_file") &
        pids+=($!)
    done
    
    # Wait for all tests to complete
    local all_passed=true
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local test_name=${test_names[$i]}
        
        if wait $pid; then
            print_success "Parallel test completed: $test_name"
        else
            print_error "Parallel test failed: $test_name"
            all_passed=false
        fi
    done
    
    if [[ "$all_passed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

print_header "🚀 Starting Comprehensive Infrastructure Testing"
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_NAME"
echo "Region: $AWS_REGION"
echo "Timestamp: $(date)"
echo "=========================================="

# Prepare common arguments
COMMON_ARGS="-e $ENVIRONMENT -p $PROJECT_NAME -r $AWS_REGION"

if [[ "$SKIP_DESTRUCTIVE" == "true" ]]; then
    COMMON_ARGS="$COMMON_ARGS --skip-destructive"
fi

# Prepare log files if output directory is specified
DEPLOYMENT_LOG=""
HEALTH_LOG=""
SECURITY_LOG=""
ALARMS_LOG=""
COMPLIANCE_LOG=""

if [[ -n "$OUTPUT_DIR" ]]; then
    DEPLOYMENT_LOG="$OUTPUT_DIR/deployment-validation.log"
    HEALTH_LOG="$OUTPUT_DIR/health-check.log"
    SECURITY_LOG="$OUTPUT_DIR/security-validation.log"
    ALARMS_LOG="$OUTPUT_DIR/cloudwatch-alarm-test.log"
    COMPLIANCE_LOG="$OUTPUT_DIR/compliance-validation.log"
fi

# Define test configurations
TEST_CONFIGS=()

if [[ "$RUN_DEPLOYMENT" == "true" ]]; then
    TEST_CONFIGS+=("Deployment Validation|./scripts/deployment-validation.sh|$COMMON_ARGS|$DEPLOYMENT_LOG")
fi

if [[ "$RUN_HEALTH" == "true" ]]; then
    TEST_CONFIGS+=("Health Check|./scripts/health-check.sh|$COMMON_ARGS|$HEALTH_LOG")
fi

if [[ "$RUN_SECURITY" == "true" ]]; then
    TEST_CONFIGS+=("Security Validation|./scripts/security-validation.sh|$COMMON_ARGS|$SECURITY_LOG")
fi

if [[ "$RUN_COMPLIANCE" == "true" ]]; then
    TEST_CONFIGS+=("Compliance Validation|./scripts/validate-compliance.sh|$COMMON_ARGS|$COMPLIANCE_LOG")
fi

# Run tests
if [[ "$PARALLEL" == "true" && ${#TEST_CONFIGS[@]} -gt 1 ]]; then
    print_status "Running tests in parallel..."
    
    # Run parallel tests (excluding alarm tests which may interfere)
    PARALLEL_CONFIGS=()
    SEQUENTIAL_CONFIGS=()
    
    for config in "${TEST_CONFIGS[@]}"; do
        if [[ "$config" == *"CloudWatch"* ]]; then
            SEQUENTIAL_CONFIGS+=("$config")
        else
            PARALLEL_CONFIGS+=("$config")
        fi
    done
    
    # Run parallel tests first
    if [[ ${#PARALLEL_CONFIGS[@]} -gt 0 ]]; then
        if ! run_parallel_tests "${PARALLEL_CONFIGS[@]}"; then
            if [[ "$CONTINUE_ON_FAILURE" != "true" ]]; then
                exit 1
            fi
        fi
    fi
    
    # Run sequential tests
    for config in "${SEQUENTIAL_CONFIGS[@]}"; do
        IFS='|' read -r test_name script_path script_args log_file <<< "$config"
        if ! run_test "$test_name" "$script_path" "$script_args" "$log_file"; then
            if [[ "$CONTINUE_ON_FAILURE" != "true" ]]; then
                exit 1
            fi
        fi
    done
else
    # Run tests sequentially
    for config in "${TEST_CONFIGS[@]}"; do
        IFS='|' read -r test_name script_path script_args log_file <<< "$config"
        if ! run_test "$test_name" "$script_path" "$script_args" "$log_file"; then
            if [[ "$CONTINUE_ON_FAILURE" != "true" ]]; then
                exit 1
            fi
        fi
    done
fi

# Run CloudWatch alarm tests separately (they may need special handling)
if [[ "$RUN_ALARMS" == "true" ]]; then
    ALARM_MODE="safe"
    if [[ "$SKIP_STRESS" != "true" && "$ENVIRONMENT" == "test" ]]; then
        ALARM_MODE="simulate"
    fi
    
    ALARM_ARGS="$COMMON_ARGS -m $ALARM_MODE"
    
    if ! run_test "CloudWatch Alarm Test" "./scripts/cloudwatch-alarm-test.sh" "$ALARM_ARGS" "$ALARMS_LOG"; then
        if [[ "$CONTINUE_ON_FAILURE" != "true" ]]; then
            exit 1
        fi
    fi
fi

# Calculate total execution time
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# Generate summary report
echo ""
echo "=========================================="
print_header "📊 COMPREHENSIVE TEST SUMMARY"
echo "=========================================="

echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_NAME"
echo "Region: $AWS_REGION"
echo "Total Duration: ${TOTAL_DURATION}s"
echo "Total Tests: $TOTAL_TESTS"
echo "Failed Tests: $FAILED_TESTS"
echo "Success Rate: $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%"
echo ""

# Print individual test results
print_header "Individual Test Results:"
for result in "${TEST_RESULTS[@]}"; do
    echo "$result"
done

# Generate detailed report if output directory is specified
if [[ -n "$OUTPUT_DIR" ]]; then
    REPORT_FILE="$OUTPUT_DIR/test-summary.json"
    
    cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "$ENVIRONMENT",
  "project": "$PROJECT_NAME",
  "region": "$AWS_REGION",
  "total_duration": $TOTAL_DURATION,
  "total_tests": $TOTAL_TESTS,
  "failed_tests": $FAILED_TESTS,
  "success_rate": $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS )),
  "test_configuration": {
    "skip_destructive": $SKIP_DESTRUCTIVE,
    "skip_stress": $SKIP_STRESS,
    "parallel": $PARALLEL,
    "continue_on_failure": $CONTINUE_ON_FAILURE
  },
  "test_categories": {
    "deployment": $RUN_DEPLOYMENT,
    "health": $RUN_HEALTH,
    "security": $RUN_SECURITY,
    "alarms": $RUN_ALARMS,
    "compliance": $RUN_COMPLIANCE
  },
  "results": [
$(IFS=$'\n'; for result in "${TEST_RESULTS[@]}"; do
    test_name=$(echo "$result" | sed 's/^[✅❌] \([^:]*\):.*$/\1/')
    status=$(echo "$result" | grep -o "PASSED\|FAILED")
    echo "    {\"test\": \"$test_name\", \"status\": \"$status\"}"
done | sed '$!s/$/,/')
  ]
}
EOF
    
    print_status "Detailed test report saved to: $REPORT_FILE"
fi

echo ""

# Final status
if [[ $FAILED_TESTS -eq 0 ]]; then
    print_success "🎉 All tests passed! Infrastructure is healthy and properly configured."
    
    if [[ -n "$OUTPUT_DIR" ]]; then
        print_status "📁 Test logs and reports available in: $OUTPUT_DIR"
    fi
    
    exit 0
else
    print_error "❌ $FAILED_TESTS test(s) failed. Please review the issues above."
    
    if [[ -n "$OUTPUT_DIR" ]]; then
        print_status "📁 Check detailed logs in: $OUTPUT_DIR"
    fi
    
    print_status "💡 Use --continue-on-failure to run all tests even when some fail"
    print_status "💡 Use --verbose for more detailed output"
    
    exit 1
fi