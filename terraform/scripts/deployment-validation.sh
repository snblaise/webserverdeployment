#!/bin/bash

# Deployment Validation Script
# Validates deployed infrastructure components and their functionality
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
TIMEOUT=300
VERBOSE=false
SKIP_DESTRUCTIVE=false
HEALTH_CHECK_INTERVAL=10
MAX_RETRIES=30

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

Validate deployed AWS infrastructure components and their functionality.

OPTIONS:
    -e, --environment ENV       Target environment (test, staging, prod, preview) [required]
    -p, --project-name NAME     Project name for resource identification [required]
    -r, --region REGION         AWS region [required]
    -t, --timeout SECONDS       Timeout for validation checks [default: 300]
    -i, --interval SECONDS      Health check interval [default: 10]
    --max-retries COUNT         Maximum retry attempts [default: 30]
    --skip-destructive          Skip tests that might affect production traffic
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    # Validate test environment
    $0 -e test -p myproject -r us-east-1

    # Validate production with conservative settings
    $0 -e prod -p myproject -r us-east-1 --skip-destructive

    # Validate with custom timeout and verbose output
    $0 -e staging -p myproject -r us-east-1 -t 600 -v

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
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -i|--interval)
            HEALTH_CHECK_INTERVAL="$2"
            shift 2
            ;;
        --max-retries)
            MAX_RETRIES="$2"
            shift 2
            ;;
        --skip-destructive)
            SKIP_DESTRUCTIVE=true
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

# Validate environment
case $ENVIRONMENT in
    test|staging|prod|preview)
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT. Must be one of: test, staging, prod, preview"
        exit 1
        ;;
esac

# Check required tools
print_status "Checking required tools..."
for tool in aws jq curl; do
    if ! command -v $tool &> /dev/null; then
        print_error "$tool is required but not installed"
        exit 1
    fi
done

# Configure AWS CLI
export AWS_DEFAULT_REGION="$AWS_REGION"
if [[ "$VERBOSE" == "true" ]]; then
    export AWS_CLI_AUTO_PROMPT=on-partial
fi

# Test AWS connectivity
print_status "Testing AWS connectivity..."
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS authentication failed. Please configure AWS credentials."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_success "Connected to AWS account: $ACCOUNT_ID in region: $AWS_REGION"

# Initialize validation results
VALIDATION_RESULTS=()
FAILED_CHECKS=0
TOTAL_CHECKS=0

# Function to add validation result
add_result() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ "$status" == "PASS" ]]; then
        print_success "✅ $check_name: $message"
        VALIDATION_RESULTS+=("✅ $check_name: PASSED - $message")
    elif [[ "$status" == "WARN" ]]; then
        print_warning "⚠️  $check_name: $message"
        VALIDATION_RESULTS+=("⚠️  $check_name: WARNING - $message")
    else
        print_error "❌ $check_name: $message"
        VALIDATION_RESULTS+=("❌ $check_name: FAILED - $message")
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Function to get resource by tags
get_resource_by_tags() {
    local resource_type="$1"
    local tag_filters="Name=tag:Project,Values=$PROJECT_NAME Name=tag:Environment,Values=$ENVIRONMENT"
    
    case $resource_type in
        "vpc")
            aws ec2 describe-vpcs --filters $tag_filters --query 'Vpcs[0].VpcId' --output text
            ;;
        "alb")
            aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME') && contains(LoadBalancerName, '$ENVIRONMENT')].LoadBalancerArn" --output text | head -1
            ;;
        "instances")
            aws ec2 describe-instances --filters $tag_filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId' --output text
            ;;
        "security-groups")
            aws ec2 describe-security-groups --filters $tag_filters --query 'SecurityGroups[].GroupId' --output text
            ;;
    esac
}

# Function to wait for resource to be ready
wait_for_resource() {
    local resource_type="$1"
    local resource_id="$2"
    local max_wait="$3"
    local check_interval="${4:-10}"
    
    local elapsed=0
    
    print_status "Waiting for $resource_type $resource_id to be ready (max ${max_wait}s)..."
    
    while [[ $elapsed -lt $max_wait ]]; do
        case $resource_type in
            "alb")
                local state=$(aws elbv2 describe-load-balancers --load-balancer-arns "$resource_id" --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null || echo "unknown")
                if [[ "$state" == "active" ]]; then
                    return 0
                fi
                ;;
            "instance")
                local state=$(aws ec2 describe-instances --instance-ids "$resource_id" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")
                if [[ "$state" == "running" ]]; then
                    # Also check status checks
                    local status=$(aws ec2 describe-instance-status --instance-ids "$resource_id" --query 'InstanceStatuses[0].InstanceStatus.Status' --output text 2>/dev/null || echo "unknown")
                    if [[ "$status" == "ok" ]]; then
                        return 0
                    fi
                fi
                ;;
        esac
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
        
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "Still waiting... (${elapsed}s elapsed)"
        fi
    done
    
    return 1
}

print_status "Starting deployment validation for environment: $ENVIRONMENT"
print_status "Project: $PROJECT_NAME, Region: $AWS_REGION"
echo "=========================================="

# 1. VPC and Network Infrastructure Validation
print_status "Validating VPC and network infrastructure..."

VPC_ID=$(get_resource_by_tags "vpc")
if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
    add_result "VPC Existence" "PASS" "VPC found: $VPC_ID"
    
    # Check subnets
    PUBLIC_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Type,Values=public" --query 'Subnets[].SubnetId' --output text)
    PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Type,Values=private" --query 'Subnets[].SubnetId' --output text)
    
    PUBLIC_COUNT=$(echo $PUBLIC_SUBNETS | wc -w)
    PRIVATE_COUNT=$(echo $PRIVATE_SUBNETS | wc -w)
    
    if [[ $PUBLIC_COUNT -ge 2 ]]; then
        add_result "Public Subnets" "PASS" "$PUBLIC_COUNT public subnets found"
    else
        add_result "Public Subnets" "FAIL" "Expected at least 2 public subnets, found $PUBLIC_COUNT"
    fi
    
    if [[ $PRIVATE_COUNT -ge 2 ]]; then
        add_result "Private Subnets" "PASS" "$PRIVATE_COUNT private subnets found"
    else
        add_result "Private Subnets" "FAIL" "Expected at least 2 private subnets, found $PRIVATE_COUNT"
    fi
    
    # Check Internet Gateway
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)
    if [[ -n "$IGW_ID" && "$IGW_ID" != "None" ]]; then
        add_result "Internet Gateway" "PASS" "Internet Gateway found: $IGW_ID"
    else
        add_result "Internet Gateway" "FAIL" "No Internet Gateway found for VPC"
    fi
    
    # Check NAT Gateway
    NAT_GW=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query 'NatGateways[0].NatGatewayId' --output text)
    if [[ -n "$NAT_GW" && "$NAT_GW" != "None" ]]; then
        add_result "NAT Gateway" "PASS" "NAT Gateway found: $NAT_GW"
    else
        add_result "NAT Gateway" "FAIL" "No available NAT Gateway found"
    fi
    
else
    add_result "VPC Existence" "FAIL" "VPC not found for project $PROJECT_NAME in environment $ENVIRONMENT"
fi

# 2. Application Load Balancer Validation
print_status "Validating Application Load Balancer..."

ALB_ARN=$(get_resource_by_tags "alb")
if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then
    add_result "ALB Existence" "PASS" "ALB found: $(basename $ALB_ARN)"
    
    # Wait for ALB to be active
    if wait_for_resource "alb" "$ALB_ARN" 120; then
        add_result "ALB Status" "PASS" "ALB is active"
        
        # Get ALB DNS name
        ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text)
        print_status "ALB DNS: $ALB_DNS"
        
        # Check ALB scheme (should be internet-facing)
        ALB_SCHEME=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].Scheme' --output text)
        if [[ "$ALB_SCHEME" == "internet-facing" ]]; then
            add_result "ALB Scheme" "PASS" "ALB is internet-facing"
        else
            add_result "ALB Scheme" "FAIL" "ALB scheme is $ALB_SCHEME, expected internet-facing"
        fi
        
        # Check target groups
        TARGET_GROUPS=$(aws elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" --query 'TargetGroups[].TargetGroupArn' --output text)
        if [[ -n "$TARGET_GROUPS" ]]; then
            add_result "Target Groups" "PASS" "Target groups configured"
            
            # Check target health
            for tg_arn in $TARGET_GROUPS; do
                HEALTHY_TARGETS=$(aws elbv2 describe-target-health --target-group-arn "$tg_arn" --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' --output text | wc -l)
                TOTAL_TARGETS=$(aws elbv2 describe-target-health --target-group-arn "$tg_arn" --query 'TargetHealthDescriptions' --output text | wc -l)
                
                if [[ $HEALTHY_TARGETS -gt 0 ]]; then
                    add_result "Target Health" "PASS" "$HEALTHY_TARGETS/$TOTAL_TARGETS targets healthy in $(basename $tg_arn)"
                else
                    add_result "Target Health" "FAIL" "No healthy targets in $(basename $tg_arn)"
                fi
            done
        else
            add_result "Target Groups" "FAIL" "No target groups found for ALB"
        fi
        
        # Test ALB connectivity (if not skipping destructive tests)
        if [[ "$SKIP_DESTRUCTIVE" != "true" ]]; then
            print_status "Testing ALB connectivity..."
            if curl -s --max-time 30 "http://$ALB_DNS" > /dev/null; then
                add_result "ALB Connectivity" "PASS" "ALB responds to HTTP requests"
            else
                add_result "ALB Connectivity" "FAIL" "ALB does not respond to HTTP requests"
            fi
        else
            add_result "ALB Connectivity" "WARN" "Skipped (destructive test disabled)"
        fi
        
    else
        add_result "ALB Status" "FAIL" "ALB is not active within timeout period"
    fi
else
    add_result "ALB Existence" "FAIL" "ALB not found"
fi

# 3. WAF Web ACL Validation
print_status "Validating AWS WAF configuration..."

if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then
    # Get WAF Web ACL associated with ALB
    WAF_ACL=$(aws wafv2 get-web-acl-for-resource --resource-arn "$ALB_ARN" --scope REGIONAL --query 'WebACL.Id' --output text 2>/dev/null || echo "None")
    
    if [[ -n "$WAF_ACL" && "$WAF_ACL" != "None" ]]; then
        add_result "WAF Association" "PASS" "WAF Web ACL associated with ALB: $WAF_ACL"
        
        # Get WAF Web ACL details
        WAF_DETAILS=$(aws wafv2 get-web-acl --scope REGIONAL --id "$WAF_ACL" --name "${PROJECT_NAME}-${ENVIRONMENT}-waf" 2>/dev/null || echo "")
        
        if [[ -n "$WAF_DETAILS" ]]; then
            # Check for managed rule groups
            MANAGED_RULES=$(echo "$WAF_DETAILS" | jq -r '.WebACL.Rules[] | select(.Statement.ManagedRuleGroupStatement) | .Statement.ManagedRuleGroupStatement.Name' 2>/dev/null || echo "")
            
            if echo "$MANAGED_RULES" | grep -q "AWSManagedRulesCommonRuleSet"; then
                add_result "WAF Common Rules" "PASS" "Common rule set configured"
            else
                add_result "WAF Common Rules" "FAIL" "Common rule set not found"
            fi
            
            if echo "$MANAGED_RULES" | grep -q "AWSManagedRulesKnownBadInputsRuleSet"; then
                add_result "WAF Bad Inputs Rules" "PASS" "Known bad inputs rule set configured"
            else
                add_result "WAF Bad Inputs Rules" "FAIL" "Known bad inputs rule set not found"
            fi
            
            # Check for rate limiting rule
            RATE_RULES=$(echo "$WAF_DETAILS" | jq -r '.WebACL.Rules[] | select(.Statement.RateBasedStatement) | .Statement.RateBasedStatement.Limit' 2>/dev/null || echo "")
            
            if [[ -n "$RATE_RULES" ]]; then
                add_result "WAF Rate Limiting" "PASS" "Rate limiting configured"
            else
                add_result "WAF Rate Limiting" "FAIL" "Rate limiting not configured"
            fi
        else
            add_result "WAF Configuration" "WARN" "Could not retrieve WAF configuration details"
        fi
    else
        add_result "WAF Association" "FAIL" "No WAF Web ACL associated with ALB"
    fi
else
    add_result "WAF Association" "WARN" "Cannot check WAF - ALB not found"
fi

# 4. EC2 Instance Validation
print_status "Validating EC2 instances..."

INSTANCE_IDS=$(get_resource_by_tags "instances")
if [[ -n "$INSTANCE_IDS" ]]; then
    INSTANCE_COUNT=$(echo $INSTANCE_IDS | wc -w)
    add_result "EC2 Instances" "PASS" "$INSTANCE_COUNT instances found"
    
    for instance_id in $INSTANCE_IDS; do
        print_status "Validating instance: $instance_id"
        
        # Wait for instance to be ready
        if wait_for_resource "instance" "$instance_id" 180; then
            add_result "Instance Status ($instance_id)" "PASS" "Instance is running and status checks passed"
        else
            add_result "Instance Status ($instance_id)" "FAIL" "Instance is not ready within timeout"
            continue
        fi
        
        # Check instance placement (should be in private subnet)
        SUBNET_ID=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].SubnetId' --output text)
        SUBNET_TYPE=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_ID" --query 'Subnets[0].Tags[?Key==`Type`].Value' --output text)
        
        if [[ "$SUBNET_TYPE" == "private" ]]; then
            add_result "Instance Placement ($instance_id)" "PASS" "Instance in private subnet"
        else
            add_result "Instance Placement ($instance_id)" "FAIL" "Instance not in private subnet (found: $SUBNET_TYPE)"
        fi
        
        # Check IMDSv2 configuration
        IMDS_CONFIG=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].MetadataOptions.HttpTokens' --output text)
        if [[ "$IMDS_CONFIG" == "required" ]]; then
            add_result "IMDSv2 ($instance_id)" "PASS" "IMDSv2 is required"
        else
            add_result "IMDSv2 ($instance_id)" "FAIL" "IMDSv2 is not required (found: $IMDS_CONFIG)"
        fi
        
        # Check EBS encryption
        VOLUME_IDS=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].BlockDeviceMappings[].Ebs.VolumeId' --output text)
        for volume_id in $VOLUME_IDS; do
            ENCRYPTED=$(aws ec2 describe-volumes --volume-ids "$volume_id" --query 'Volumes[0].Encrypted' --output text)
            if [[ "$ENCRYPTED" == "true" ]]; then
                add_result "EBS Encryption ($volume_id)" "PASS" "Volume is encrypted"
            else
                add_result "EBS Encryption ($volume_id)" "FAIL" "Volume is not encrypted"
            fi
        done
        
        # Check SSM connectivity
        SSM_STATUS=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$instance_id" --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || echo "Unknown")
        if [[ "$SSM_STATUS" == "Online" ]]; then
            add_result "SSM Connectivity ($instance_id)" "PASS" "SSM agent is online"
        else
            add_result "SSM Connectivity ($instance_id)" "FAIL" "SSM agent status: $SSM_STATUS"
        fi
    done
else
    add_result "EC2 Instances" "FAIL" "No running instances found"
fi

# 5. Security Groups Validation
print_status "Validating security groups..."

SECURITY_GROUPS=$(get_resource_by_tags "security-groups")
if [[ -n "$SECURITY_GROUPS" ]]; then
    SG_COUNT=$(echo $SECURITY_GROUPS | wc -w)
    add_result "Security Groups" "PASS" "$SG_COUNT security groups found"
    
    for sg_id in $SECURITY_GROUPS; do
        # Check for overly permissive rules (0.0.0.0/0)
        PERMISSIVE_RULES=$(aws ec2 describe-security-groups --group-ids "$sg_id" --query 'SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]' --output text)
        
        if [[ -z "$PERMISSIVE_RULES" ]]; then
            add_result "Security Group Rules ($sg_id)" "PASS" "No overly permissive rules found"
        else
            # Check if it's ALB security group (allowed to have 0.0.0.0/0 for HTTP)
            SG_NAME=$(aws ec2 describe-security-groups --group-ids "$sg_id" --query 'SecurityGroups[0].GroupName' --output text)
            if [[ "$SG_NAME" == *"alb"* ]]; then
                add_result "Security Group Rules ($sg_id)" "PASS" "ALB security group with controlled public access"
            else
                add_result "Security Group Rules ($sg_id)" "WARN" "Permissive rules found in non-ALB security group"
            fi
        fi
    done
else
    add_result "Security Groups" "FAIL" "No security groups found"
fi

echo ""
echo "=========================================="
echo "           VALIDATION SUMMARY"
echo "=========================================="

# Print all results
for result in "${VALIDATION_RESULTS[@]}"; do
    echo "$result"
done

echo ""
echo "Total Checks: $TOTAL_CHECKS"
echo "Failed Checks: $FAILED_CHECKS"
echo "Success Rate: $(( (TOTAL_CHECKS - FAILED_CHECKS) * 100 / TOTAL_CHECKS ))%"

if [[ $FAILED_CHECKS -eq 0 ]]; then
    print_success "🎉 All validation checks passed! Infrastructure is properly deployed and configured."
    exit 0
else
    print_error "❌ $FAILED_CHECKS validation check(s) failed. Please review and fix the issues above."
    exit 1
fi