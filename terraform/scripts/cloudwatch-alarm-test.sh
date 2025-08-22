#!/bin/bash

# CloudWatch Alarm Testing Script
# Tests CloudWatch alarms and SNS notifications functionality
# Requirements: 4.1, 4.2, 4.3

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="test"
PROJECT_NAME=""
AWS_REGION=""
TEST_MODE="safe"
VERBOSE=false
WAIT_TIME=300
CHECK_INTERVAL=30

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

Test CloudWatch alarms and SNS notifications functionality.

OPTIONS:
    -e, --environment ENV       Target environment (test, staging, prod, preview) [required]
    -p, --project-name NAME     Project name for resource identification [required]
    -r, --region REGION         AWS region [required]
    -m, --mode MODE             Test mode (safe, simulate, stress) [default: safe]
    -w, --wait-time SECONDS     Maximum wait time for alarm state changes [default: 300]
    -i, --interval SECONDS      Check interval for alarm states [default: 30]
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

TEST MODES:
    safe        - Only check existing alarm states and configurations
    simulate    - Use CloudWatch alarm state change simulation (recommended)
    stress      - Generate actual load to trigger alarms (use with caution)

EXAMPLES:
    # Safe mode - check alarm configurations only
    $0 -e test -p myproject -r us-east-1

    # Simulate alarm state changes
    $0 -e test -p myproject -r us-east-1 -m simulate

    # Stress test (use carefully, may affect performance)
    $0 -e test -p myproject -r us-east-1 -m stress

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
        -m|--mode)
            TEST_MODE="$2"
            shift 2
            ;;
        -w|--wait-time)
            WAIT_TIME="$2"
            shift 2
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
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

# Validate test mode
case $TEST_MODE in
    safe|simulate|stress)
        ;;
    *)
        print_error "Invalid test mode: $TEST_MODE. Must be one of: safe, simulate, stress"
        exit 1
        ;;
esac

# Check required tools
for tool in aws jq; do
    if ! command -v $tool &> /dev/null; then
        print_error "$tool is required but not installed"
        exit 1
    fi
done

# Configure AWS CLI
export AWS_DEFAULT_REGION="$AWS_REGION"

# Test AWS connectivity
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS authentication failed. Please configure AWS credentials."
    exit 1
fi

# Initialize test results
TEST_RESULTS=()
FAILED_TESTS=0
TOTAL_TESTS=0

# Function to add test result
add_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$status" == "PASS" ]]; then
        print_success "✅ $test_name: $message"
        TEST_RESULTS+=("✅ $test_name: PASSED - $message")
    elif [[ "$status" == "WARN" ]]; then
        print_warning "⚠️  $test_name: $message"
        TEST_RESULTS+=("⚠️  $test_name: WARNING - $message")
    else
        print_error "❌ $test_name: $message"
        TEST_RESULTS+=("❌ $test_name: FAILED - $message")
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Function to wait for alarm state change
wait_for_alarm_state() {
    local alarm_name="$1"
    local expected_state="$2"
    local max_wait="$3"
    local check_interval="${4:-30}"
    
    local elapsed=0
    
    print_status "Waiting for alarm $alarm_name to reach state $expected_state (max ${max_wait}s)..."
    
    while [[ $elapsed -lt $max_wait ]]; do
        local current_state=$(aws cloudwatch describe-alarms --alarm-names "$alarm_name" --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null || echo "UNKNOWN")
        
        if [[ "$current_state" == "$expected_state" ]]; then
            print_success "Alarm $alarm_name reached state $expected_state after ${elapsed}s"
            return 0
        fi
        
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "Current state: $current_state, waiting for: $expected_state (${elapsed}s elapsed)"
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    print_warning "Alarm $alarm_name did not reach state $expected_state within ${max_wait}s"
    return 1
}

# Function to get resource IDs
get_resource_ids() {
    local tag_filters="Name=tag:Project,Values=$PROJECT_NAME Name=tag:Environment,Values=$ENVIRONMENT"
    
    # Get instance IDs
    INSTANCE_IDS=$(aws ec2 describe-instances --filters $tag_filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || echo "")
    
    # Get ALB ARN
    ALB_ARN=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME') && contains(LoadBalancerName, '$ENVIRONMENT')].LoadBalancerArn" --output text 2>/dev/null | head -1 || echo "")
    
    # Get SNS topic ARN
    SNS_TOPIC_ARN=$(aws sns list-topics --query "Topics[?contains(TopicArn, '$PROJECT_NAME') && contains(TopicArn, '$ENVIRONMENT')].TopicArn" --output text 2>/dev/null | head -1 || echo "")
}

print_status "Starting CloudWatch alarm testing for environment: $ENVIRONMENT"
print_status "Project: $PROJECT_NAME, Region: $AWS_REGION, Mode: $TEST_MODE"
echo "=========================================="

# Get resource information
get_resource_ids

# 1. Discover and validate alarms
print_status "Discovering CloudWatch alarms..."

ALARM_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"
ALARMS=$(aws cloudwatch describe-alarms --alarm-name-prefix "$ALARM_PREFIX" --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Actions:AlarmActions[]}' --output json 2>/dev/null || echo "[]")

ALARM_COUNT=$(echo "$ALARMS" | jq length)

if [[ $ALARM_COUNT -eq 0 ]]; then
    add_test_result "Alarm Discovery" "FAIL" "No CloudWatch alarms found with prefix $ALARM_PREFIX"
    exit 1
else
    add_test_result "Alarm Discovery" "PASS" "Found $ALARM_COUNT CloudWatch alarms"
fi

# List discovered alarms
if [[ "$VERBOSE" == "true" ]]; then
    print_status "Discovered alarms:"
    echo "$ALARMS" | jq -r '.[] | "  - \(.Name): \(.State)"'
fi

# 2. Validate alarm configurations
print_status "Validating alarm configurations..."

for i in $(seq 0 $((ALARM_COUNT - 1))); do
    ALARM_NAME=$(echo "$ALARMS" | jq -r ".[$i].Name")
    ALARM_STATE=$(echo "$ALARMS" | jq -r ".[$i].State")
    ALARM_ACTIONS=$(echo "$ALARMS" | jq -r ".[$i].Actions[]" 2>/dev/null || echo "")
    
    # Check if alarm has actions configured
    if [[ -n "$ALARM_ACTIONS" ]]; then
        add_test_result "Alarm Actions ($ALARM_NAME)" "PASS" "Alarm has actions configured"
        
        # Check if SNS topic is in the actions
        if echo "$ALARM_ACTIONS" | grep -q "arn:aws:sns"; then
            add_test_result "SNS Action ($ALARM_NAME)" "PASS" "SNS action configured"
        else
            add_test_result "SNS Action ($ALARM_NAME)" "WARN" "No SNS action found"
        fi
    else
        add_test_result "Alarm Actions ($ALARM_NAME)" "FAIL" "No actions configured for alarm"
    fi
    
    # Get detailed alarm configuration
    ALARM_DETAILS=$(aws cloudwatch describe-alarms --alarm-names "$ALARM_NAME" --query 'MetricAlarms[0]' --output json 2>/dev/null)
    
    if [[ -n "$ALARM_DETAILS" ]]; then
        METRIC_NAME=$(echo "$ALARM_DETAILS" | jq -r '.MetricName // "unknown"')
        NAMESPACE=$(echo "$ALARM_DETAILS" | jq -r '.Namespace // "unknown"')
        THRESHOLD=$(echo "$ALARM_DETAILS" | jq -r '.Threshold // 0')
        COMPARISON=$(echo "$ALARM_DETAILS" | jq -r '.ComparisonOperator // "unknown"')
        
        add_test_result "Alarm Configuration ($ALARM_NAME)" "PASS" "Metric: $NAMESPACE/$METRIC_NAME, Threshold: $THRESHOLD ($COMPARISON)"
    else
        add_test_result "Alarm Configuration ($ALARM_NAME)" "FAIL" "Could not retrieve alarm details"
    fi
done

# 3. Validate SNS topic and subscriptions
print_status "Validating SNS configuration..."

if [[ -n "$SNS_TOPIC_ARN" ]]; then
    add_test_result "SNS Topic" "PASS" "SNS topic found: $(basename "$SNS_TOPIC_ARN")"
    
    # Check subscriptions
    SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic --topic-arn "$SNS_TOPIC_ARN" --query 'Subscriptions[].{Protocol:Protocol,Endpoint:Endpoint,Status:SubscriptionArn}' --output json 2>/dev/null || echo "[]")
    
    SUBSCRIPTION_COUNT=$(echo "$SUBSCRIPTIONS" | jq length)
    
    if [[ $SUBSCRIPTION_COUNT -gt 0 ]]; then
        add_test_result "SNS Subscriptions" "PASS" "$SUBSCRIPTION_COUNT subscriptions configured"
        
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "SNS subscriptions:"
            echo "$SUBSCRIPTIONS" | jq -r '.[] | "  - \(.Protocol): \(.Endpoint)"'
        fi
    else
        add_test_result "SNS Subscriptions" "WARN" "No subscriptions configured for SNS topic"
    fi
else
    add_test_result "SNS Topic" "FAIL" "No SNS topic found"
fi

# 4. Test alarm functionality based on mode
case $TEST_MODE in
    "safe")
        print_status "Safe mode: Skipping alarm state manipulation tests"
        add_test_result "Alarm State Test" "PASS" "Safe mode - configuration validation only"
        ;;
        
    "simulate")
        print_status "Simulate mode: Testing alarm state changes using CloudWatch API"
        
        # Find a suitable alarm to test
        TEST_ALARM=$(echo "$ALARMS" | jq -r '.[0].Name' 2>/dev/null)
        
        if [[ -n "$TEST_ALARM" && "$TEST_ALARM" != "null" ]]; then
            ORIGINAL_STATE=$(echo "$ALARMS" | jq -r ".[] | select(.Name == \"$TEST_ALARM\") | .State")
            
            print_status "Testing alarm: $TEST_ALARM (original state: $ORIGINAL_STATE)"
            
            # Set alarm to ALARM state
            print_status "Setting alarm to ALARM state..."
            if aws cloudwatch set-alarm-state --alarm-name "$TEST_ALARM" --state-value ALARM --state-reason "Testing alarm functionality" 2>/dev/null; then
                add_test_result "Alarm State Change (ALARM)" "PASS" "Successfully set alarm to ALARM state"
                
                # Wait a bit for the state change to propagate
                sleep 10
                
                # Check if state changed
                NEW_STATE=$(aws cloudwatch describe-alarms --alarm-names "$TEST_ALARM" --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null)
                
                if [[ "$NEW_STATE" == "ALARM" ]]; then
                    add_test_result "Alarm State Verification (ALARM)" "PASS" "Alarm state successfully changed to ALARM"
                else
                    add_test_result "Alarm State Verification (ALARM)" "FAIL" "Alarm state is $NEW_STATE, expected ALARM"
                fi
                
                # Reset to OK state
                print_status "Resetting alarm to OK state..."
                if aws cloudwatch set-alarm-state --alarm-name "$TEST_ALARM" --state-value OK --state-reason "Resetting after test" 2>/dev/null; then
                    add_test_result "Alarm State Reset (OK)" "PASS" "Successfully reset alarm to OK state"
                    
                    # Wait for state change
                    sleep 10
                    
                    RESET_STATE=$(aws cloudwatch describe-alarms --alarm-names "$TEST_ALARM" --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null)
                    
                    if [[ "$RESET_STATE" == "OK" ]]; then
                        add_test_result "Alarm State Verification (OK)" "PASS" "Alarm state successfully reset to OK"
                    else
                        add_test_result "Alarm State Verification (OK)" "WARN" "Alarm state is $RESET_STATE, may need manual reset"
                    fi
                else
                    add_test_result "Alarm State Reset (OK)" "FAIL" "Failed to reset alarm state"
                fi
            else
                add_test_result "Alarm State Change (ALARM)" "FAIL" "Failed to set alarm to ALARM state"
            fi
        else
            add_test_result "Alarm State Test" "FAIL" "No suitable alarm found for testing"
        fi
        ;;
        
    "stress")
        print_warning "Stress mode: This will generate actual load and may affect system performance"
        print_status "Proceeding with stress testing in 5 seconds... (Ctrl+C to cancel)"
        sleep 5
        
        # Find CPU alarm for testing
        CPU_ALARM=$(echo "$ALARMS" | jq -r '.[] | select(.Name | contains("cpu") or contains("CPU")) | .Name' | head -1)
        
        if [[ -n "$CPU_ALARM" && "$CPU_ALARM" != "null" ]]; then
            print_status "Found CPU alarm for stress testing: $CPU_ALARM"
            
            if [[ -n "$INSTANCE_IDS" ]]; then
                TEST_INSTANCE=$(echo $INSTANCE_IDS | awk '{print $1}')
                print_status "Using instance for stress test: $TEST_INSTANCE"
                
                # Generate CPU load using SSM
                print_status "Generating CPU load via SSM..."
                
                COMMAND_ID=$(aws ssm send-command \
                    --instance-ids "$TEST_INSTANCE" \
                    --document-name "AWS-RunShellScript" \
                    --parameters 'commands=["stress --cpu 1 --timeout 120s || (for i in {1..120}; do echo \"Generating load...\"; dd if=/dev/zero of=/dev/null bs=1M count=100 2>/dev/null & done; sleep 120; killall dd 2>/dev/null || true)"]' \
                    --query 'Command.CommandId' --output text 2>/dev/null || echo "")
                
                if [[ -n "$COMMAND_ID" ]]; then
                    add_test_result "Stress Test Command" "PASS" "CPU stress test command sent (ID: $COMMAND_ID)"
                    
                    # Wait for alarm to trigger
                    print_status "Waiting for CPU alarm to trigger (this may take several minutes)..."
                    
                    if wait_for_alarm_state "$CPU_ALARM" "ALARM" "$WAIT_TIME" "$CHECK_INTERVAL"; then
                        add_test_result "CPU Alarm Trigger" "PASS" "CPU alarm successfully triggered by stress test"
                    else
                        add_test_result "CPU Alarm Trigger" "WARN" "CPU alarm did not trigger within timeout (may need longer duration)"
                    fi
                    
                    # Wait for alarm to return to OK
                    print_status "Waiting for CPU alarm to return to OK state..."
                    
                    if wait_for_alarm_state "$CPU_ALARM" "OK" "$WAIT_TIME" "$CHECK_INTERVAL"; then
                        add_test_result "CPU Alarm Recovery" "PASS" "CPU alarm returned to OK state"
                    else
                        add_test_result "CPU Alarm Recovery" "WARN" "CPU alarm did not return to OK within timeout"
                    fi
                else
                    add_test_result "Stress Test Command" "FAIL" "Failed to send CPU stress test command"
                fi
            else
                add_test_result "Stress Test Setup" "FAIL" "No instances available for stress testing"
            fi
        else
            add_test_result "CPU Alarm Discovery" "FAIL" "No CPU alarm found for stress testing"
        fi
        ;;
esac

# 5. Test SNS message delivery (if in simulate mode)
if [[ "$TEST_MODE" == "simulate" && -n "$SNS_TOPIC_ARN" ]]; then
    print_status "Testing SNS message delivery..."
    
    TEST_MESSAGE="CloudWatch Alarm Test - $(date)"
    TEST_SUBJECT="Test Notification from $PROJECT_NAME-$ENVIRONMENT"
    
    if aws sns publish --topic-arn "$SNS_TOPIC_ARN" --message "$TEST_MESSAGE" --subject "$TEST_SUBJECT" 2>/dev/null; then
        add_test_result "SNS Message Delivery" "PASS" "Test message sent to SNS topic"
    else
        add_test_result "SNS Message Delivery" "FAIL" "Failed to send test message to SNS topic"
    fi
fi

# Summary
echo ""
echo "=========================================="
echo "      CLOUDWATCH ALARM TEST SUMMARY"
echo "=========================================="

# Print all results
for result in "${TEST_RESULTS[@]}"; do
    echo "$result"
done

echo ""
echo "Total Tests: $TOTAL_TESTS"
echo "Failed Tests: $FAILED_TESTS"
echo "Success Rate: $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%"

if [[ $FAILED_TESTS -eq 0 ]]; then
    print_success "🎉 All CloudWatch alarm tests passed!"
    
    if [[ "$TEST_MODE" == "safe" ]]; then
        print_status "💡 Run with -m simulate to test alarm state changes"
        print_status "💡 Run with -m stress to test with actual load (use carefully)"
    fi
    
    exit 0
else
    print_error "❌ $FAILED_TESTS CloudWatch alarm test(s) failed. Please review and fix the issues above."
    exit 1
fi