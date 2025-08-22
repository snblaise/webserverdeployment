#!/bin/bash

# Security Validation Script
# Validates security configurations and compliance of deployed infrastructure
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
VERBOSE=false
OUTPUT_FORMAT="console"
STRICT_MODE=false
COMPLIANCE_ONLY=false

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

Validate security configurations and compliance of deployed AWS infrastructure.

OPTIONS:
    -e, --environment ENV       Target environment (test, staging, prod, preview) [required]
    -p, --project-name NAME     Project name for resource identification [required]
    -r, --region REGION         AWS region [required]
    -f, --format FORMAT         Output format (console, json, csv) [default: console]
    -s, --strict                Enable strict mode (fail on warnings)
    -c, --compliance-only       Only run compliance checks, skip security scans
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    # Basic security validation
    $0 -e test -p myproject -r us-east-1

    # Strict mode for production
    $0 -e prod -p myproject -r us-east-1 -s

    # JSON output for automation
    $0 -e staging -p myproject -r us-east-1 -f json

    # Compliance checks only
    $0 -e test -p myproject -r us-east-1 -c

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
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -s|--strict)
            STRICT_MODE=true
            shift
            ;;
        -c|--compliance-only)
            COMPLIANCE_ONLY=true
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

# Initialize validation results
VALIDATION_RESULTS=()
FAILED_CHECKS=0
WARNING_CHECKS=0
TOTAL_CHECKS=0

# Function to add validation result
add_result() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    local severity="${4:-MEDIUM}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case $status in
        "PASS")
            if [[ "$OUTPUT_FORMAT" == "console" ]]; then
                print_success "✅ $check_name: $message"
            fi
            VALIDATION_RESULTS+=("{\"check\":\"$check_name\",\"status\":\"PASS\",\"message\":\"$message\",\"severity\":\"$severity\"}")
            ;;
        "WARN")
            if [[ "$OUTPUT_FORMAT" == "console" ]]; then
                print_warning "⚠️  $check_name: $message"
            fi
            VALIDATION_RESULTS+=("{\"check\":\"$check_name\",\"status\":\"WARN\",\"message\":\"$message\",\"severity\":\"$severity\"}")
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            if [[ "$STRICT_MODE" == "true" ]]; then
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
            fi
            ;;
        "FAIL")
            if [[ "$OUTPUT_FORMAT" == "console" ]]; then
                print_error "❌ $check_name: $message"
            fi
            VALIDATION_RESULTS+=("{\"check\":\"$check_name\",\"status\":\"FAIL\",\"message\":\"$message\",\"severity\":\"$severity\"}")
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            ;;
    esac
}

# Function to get resource by tags
get_resource_by_tags() {
    local resource_type="$1"
    local tag_filters="Name=tag:Project,Values=$PROJECT_NAME Name=tag:Environment,Values=$ENVIRONMENT"
    
    case $resource_type in
        "vpc")
            aws ec2 describe-vpcs --filters $tag_filters --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None"
            ;;
        "instances")
            aws ec2 describe-instances --filters $tag_filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || echo ""
            ;;
        "security-groups")
            aws ec2 describe-security-groups --filters $tag_filters --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo ""
            ;;
        "alb")
            aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME') && contains(LoadBalancerName, '$ENVIRONMENT')].LoadBalancerArn" --output text 2>/dev/null | head -1 || echo "None"
            ;;
    esac
}

print_status "Starting security validation for environment: $ENVIRONMENT"
print_status "Project: $PROJECT_NAME, Region: $AWS_REGION"
echo "=========================================="

# 1. IMDSv2 Validation
print_status "Validating IMDSv2 configuration..."

INSTANCE_IDS=$(get_resource_by_tags "instances")
if [[ -n "$INSTANCE_IDS" ]]; then
    for instance_id in $INSTANCE_IDS; do
        IMDS_CONFIG=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].MetadataOptions' --output json 2>/dev/null)
        
        if [[ -n "$IMDS_CONFIG" ]]; then
            HTTP_TOKENS=$(echo "$IMDS_CONFIG" | jq -r '.HttpTokens // "optional"')
            HTTP_PUT_RESPONSE_HOP_LIMIT=$(echo "$IMDS_CONFIG" | jq -r '.HttpPutResponseHopLimit // 2')
            HTTP_ENDPOINT=$(echo "$IMDS_CONFIG" | jq -r '.HttpEndpoint // "enabled"')
            
            if [[ "$HTTP_TOKENS" == "required" ]]; then
                add_result "IMDSv2 Tokens ($instance_id)" "PASS" "IMDSv2 tokens required" "HIGH"
            else
                add_result "IMDSv2 Tokens ($instance_id)" "FAIL" "IMDSv2 tokens not required (found: $HTTP_TOKENS)" "HIGH"
            fi
            
            if [[ "$HTTP_PUT_RESPONSE_HOP_LIMIT" -eq 1 ]]; then
                add_result "IMDSv2 Hop Limit ($instance_id)" "PASS" "Hop limit set to 1" "MEDIUM"
            else
                add_result "IMDSv2 Hop Limit ($instance_id)" "WARN" "Hop limit is $HTTP_PUT_RESPONSE_HOP_LIMIT (recommended: 1)" "MEDIUM"
            fi
            
            if [[ "$HTTP_ENDPOINT" == "enabled" ]]; then
                add_result "IMDS Endpoint ($instance_id)" "PASS" "IMDS endpoint enabled" "LOW"
            else
                add_result "IMDS Endpoint ($instance_id)" "WARN" "IMDS endpoint disabled" "LOW"
            fi
        else
            add_result "IMDSv2 Configuration ($instance_id)" "FAIL" "Could not retrieve IMDS configuration" "HIGH"
        fi
    done
else
    add_result "IMDSv2 Validation" "WARN" "No running instances found" "MEDIUM"
fi

# 2. EBS Encryption Validation
print_status "Validating EBS encryption..."

if [[ -n "$INSTANCE_IDS" ]]; then
    for instance_id in $INSTANCE_IDS; do
        VOLUME_IDS=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].BlockDeviceMappings[].Ebs.VolumeId' --output text 2>/dev/null)
        
        for volume_id in $VOLUME_IDS; do
            VOLUME_INFO=$(aws ec2 describe-volumes --volume-ids "$volume_id" --query 'Volumes[0]' --output json 2>/dev/null)
            
            if [[ -n "$VOLUME_INFO" ]]; then
                ENCRYPTED=$(echo "$VOLUME_INFO" | jq -r '.Encrypted // false')
                KMS_KEY_ID=$(echo "$VOLUME_INFO" | jq -r '.KmsKeyId // "none"')
                VOLUME_TYPE=$(echo "$VOLUME_INFO" | jq -r '.VolumeType // "unknown"')
                
                if [[ "$ENCRYPTED" == "true" ]]; then
                    add_result "EBS Encryption ($volume_id)" "PASS" "Volume encrypted with key: $(basename "$KMS_KEY_ID")" "HIGH"
                else
                    add_result "EBS Encryption ($volume_id)" "FAIL" "Volume not encrypted" "HIGH"
                fi
                
                if [[ "$VOLUME_TYPE" == "gp3" ]]; then
                    add_result "EBS Volume Type ($volume_id)" "PASS" "Using GP3 volume type" "LOW"
                elif [[ "$VOLUME_TYPE" == "gp2" ]]; then
                    add_result "EBS Volume Type ($volume_id)" "WARN" "Using GP2 volume type (consider GP3)" "LOW"
                else
                    add_result "EBS Volume Type ($volume_id)" "WARN" "Using $VOLUME_TYPE volume type" "LOW"
                fi
            else
                add_result "EBS Volume Info ($volume_id)" "FAIL" "Could not retrieve volume information" "MEDIUM"
            fi
        done
    done
fi

# 3. Security Group Validation
print_status "Validating security group configurations..."

SECURITY_GROUPS=$(get_resource_by_tags "security-groups")
if [[ -n "$SECURITY_GROUPS" ]]; then
    for sg_id in $SECURITY_GROUPS; do
        SG_INFO=$(aws ec2 describe-security-groups --group-ids "$sg_id" --query 'SecurityGroups[0]' --output json 2>/dev/null)
        
        if [[ -n "$SG_INFO" ]]; then
            SG_NAME=$(echo "$SG_INFO" | jq -r '.GroupName // "unknown"')
            
            # Check for overly permissive inbound rules
            PERMISSIVE_INBOUND=$(echo "$SG_INFO" | jq -r '.IpPermissions[] | select(.IpRanges[]?.CidrIp == "0.0.0.0/0") | .FromPort // "all"' 2>/dev/null)
            
            if [[ -n "$PERMISSIVE_INBOUND" ]]; then
                # Allow 0.0.0.0/0 for ALB security groups on HTTP/HTTPS
                if [[ "$SG_NAME" == *"alb"* ]] && [[ "$PERMISSIVE_INBOUND" == "80" || "$PERMISSIVE_INBOUND" == "443" ]]; then
                    add_result "Security Group Inbound ($sg_id)" "PASS" "ALB security group with controlled public access" "MEDIUM"
                else
                    add_result "Security Group Inbound ($sg_id)" "FAIL" "Overly permissive inbound rule (0.0.0.0/0) on port $PERMISSIVE_INBOUND" "HIGH"
                fi
            else
                add_result "Security Group Inbound ($sg_id)" "PASS" "No overly permissive inbound rules" "MEDIUM"
            fi
            
            # Check for overly permissive outbound rules
            PERMISSIVE_OUTBOUND=$(echo "$SG_INFO" | jq -r '.IpPermissionsEgress[] | select(.IpRanges[]?.CidrIp == "0.0.0.0/0") | .FromPort // "all"' 2>/dev/null)
            
            if [[ -n "$PERMISSIVE_OUTBOUND" ]]; then
                # Outbound 0.0.0.0/0 is more acceptable but should be noted
                add_result "Security Group Outbound ($sg_id)" "WARN" "Outbound rule allows all traffic (0.0.0.0/0)" "LOW"
            else
                add_result "Security Group Outbound ($sg_id)" "PASS" "Restricted outbound rules" "LOW"
            fi
            
            # Check for unused security groups
            ATTACHED_INSTANCES=$(aws ec2 describe-instances --filters "Name=instance.group-id,Values=$sg_id" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null)
            ATTACHED_ALBS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?SecurityGroups && contains(SecurityGroups, '$sg_id')].LoadBalancerArn" --output text 2>/dev/null)
            
            if [[ -z "$ATTACHED_INSTANCES" && -z "$ATTACHED_ALBS" ]]; then
                add_result "Security Group Usage ($sg_id)" "WARN" "Security group not attached to any resources" "LOW"
            else
                add_result "Security Group Usage ($sg_id)" "PASS" "Security group in use" "LOW"
            fi
        else
            add_result "Security Group Info ($sg_id)" "FAIL" "Could not retrieve security group information" "MEDIUM"
        fi
    done
else
    add_result "Security Groups" "WARN" "No security groups found" "MEDIUM"
fi

# 4. Network Isolation Validation
print_status "Validating network isolation..."

VPC_ID=$(get_resource_by_tags "vpc")
if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
    # Check if instances are in private subnets
    if [[ -n "$INSTANCE_IDS" ]]; then
        for instance_id in $INSTANCE_IDS; do
            SUBNET_ID=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].SubnetId' --output text 2>/dev/null)
            PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null)
            
            if [[ -n "$SUBNET_ID" ]]; then
                # Check if subnet has route to Internet Gateway (indicates public subnet)
                ROUTE_TABLE=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SUBNET_ID" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null)
                
                if [[ -n "$ROUTE_TABLE" && "$ROUTE_TABLE" != "None" ]]; then
                    IGW_ROUTE=$(aws ec2 describe-route-tables --route-table-ids "$ROUTE_TABLE" --query 'RouteTables[0].Routes[?GatewayId && starts_with(GatewayId, `igw-`)]' --output text 2>/dev/null)
                    
                    if [[ -z "$IGW_ROUTE" ]]; then
                        add_result "Network Isolation ($instance_id)" "PASS" "Instance in private subnet" "HIGH"
                    else
                        add_result "Network Isolation ($instance_id)" "FAIL" "Instance in public subnet" "HIGH"
                    fi
                else
                    add_result "Network Isolation ($instance_id)" "WARN" "Could not determine subnet type" "MEDIUM"
                fi
            fi
            
            # Check for public IP assignment
            if [[ "$PUBLIC_IP" == "None" || -z "$PUBLIC_IP" ]]; then
                add_result "Public IP Assignment ($instance_id)" "PASS" "No public IP assigned" "HIGH"
            else
                add_result "Public IP Assignment ($instance_id)" "FAIL" "Public IP assigned: $PUBLIC_IP" "HIGH"
            fi
        done
    fi
    
    # Check VPC endpoints
    VPC_ENDPOINTS=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[].ServiceName' --output text 2>/dev/null)
    
    REQUIRED_ENDPOINTS=("com.amazonaws.$AWS_REGION.ssm" "com.amazonaws.$AWS_REGION.ec2messages" "com.amazonaws.$AWS_REGION.ssmmessages")
    
    for endpoint in "${REQUIRED_ENDPOINTS[@]}"; do
        if echo "$VPC_ENDPOINTS" | grep -q "$endpoint"; then
            add_result "VPC Endpoint ($endpoint)" "PASS" "VPC endpoint configured" "MEDIUM"
        else
            add_result "VPC Endpoint ($endpoint)" "WARN" "VPC endpoint not configured (increases NAT usage)" "LOW"
        fi
    done
fi

# 5. WAF Configuration Validation
print_status "Validating WAF configuration..."

ALB_ARN=$(get_resource_by_tags "alb")
if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then
    WAF_ACL=$(aws wafv2 get-web-acl-for-resource --resource-arn "$ALB_ARN" --scope REGIONAL --query 'WebACL.Id' --output text 2>/dev/null || echo "None")
    
    if [[ -n "$WAF_ACL" && "$WAF_ACL" != "None" ]]; then
        add_result "WAF Association" "PASS" "WAF Web ACL associated with ALB" "HIGH"
        
        # Get WAF configuration details
        WAF_NAME="${PROJECT_NAME}-${ENVIRONMENT}-waf"
        WAF_DETAILS=$(aws wafv2 get-web-acl --scope REGIONAL --id "$WAF_ACL" --name "$WAF_NAME" 2>/dev/null || echo "")
        
        if [[ -n "$WAF_DETAILS" ]]; then
            # Check for managed rule groups
            COMMON_RULES=$(echo "$WAF_DETAILS" | jq -r '.WebACL.Rules[] | select(.Statement.ManagedRuleGroupStatement.Name == "AWSManagedRulesCommonRuleSet") | .Name' 2>/dev/null)
            BAD_INPUTS_RULES=$(echo "$WAF_DETAILS" | jq -r '.WebACL.Rules[] | select(.Statement.ManagedRuleGroupStatement.Name == "AWSManagedRulesKnownBadInputsRuleSet") | .Name' 2>/dev/null)
            RATE_LIMIT_RULES=$(echo "$WAF_DETAILS" | jq -r '.WebACL.Rules[] | select(.Statement.RateBasedStatement) | .Statement.RateBasedStatement.Limit' 2>/dev/null)
            
            if [[ -n "$COMMON_RULES" ]]; then
                add_result "WAF Common Rules" "PASS" "Common rule set configured" "HIGH"
            else
                add_result "WAF Common Rules" "FAIL" "Common rule set not configured" "HIGH"
            fi
            
            if [[ -n "$BAD_INPUTS_RULES" ]]; then
                add_result "WAF Bad Inputs Rules" "PASS" "Known bad inputs rule set configured" "HIGH"
            else
                add_result "WAF Bad Inputs Rules" "FAIL" "Known bad inputs rule set not configured" "HIGH"
            fi
            
            if [[ -n "$RATE_LIMIT_RULES" ]]; then
                if [[ "$RATE_LIMIT_RULES" -le 5000 ]]; then
                    add_result "WAF Rate Limiting" "PASS" "Rate limiting configured (limit: $RATE_LIMIT_RULES)" "MEDIUM"
                else
                    add_result "WAF Rate Limiting" "WARN" "Rate limit may be too high (limit: $RATE_LIMIT_RULES)" "MEDIUM"
                fi
            else
                add_result "WAF Rate Limiting" "FAIL" "Rate limiting not configured" "MEDIUM"
            fi
            
            # Check WAF logging
            LOGGING_CONFIG=$(aws wafv2 get-logging-configuration --resource-arn "arn:aws:wafv2:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):regional/webacl/$WAF_NAME/$WAF_ACL" 2>/dev/null || echo "")
            
            if [[ -n "$LOGGING_CONFIG" ]]; then
                add_result "WAF Logging" "PASS" "WAF logging configured" "LOW"
            else
                add_result "WAF Logging" "WARN" "WAF logging not configured" "LOW"
            fi
        else
            add_result "WAF Configuration" "WARN" "Could not retrieve WAF configuration details" "MEDIUM"
        fi
    else
        add_result "WAF Association" "FAIL" "No WAF Web ACL associated with ALB" "HIGH"
    fi
else
    add_result "WAF Validation" "WARN" "Cannot validate WAF - ALB not found" "MEDIUM"
fi

# 6. IAM Security Validation
print_status "Validating IAM security..."

# Check EC2 instance profiles
if [[ -n "$INSTANCE_IDS" ]]; then
    for instance_id in $INSTANCE_IDS; do
        IAM_PROFILE=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text 2>/dev/null || echo "None")
        
        if [[ -n "$IAM_PROFILE" && "$IAM_PROFILE" != "None" ]]; then
            add_result "IAM Instance Profile ($instance_id)" "PASS" "IAM instance profile attached" "MEDIUM"
            
            # Extract role name from instance profile ARN
            PROFILE_NAME=$(basename "$IAM_PROFILE")
            ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" --query 'InstanceProfile.Roles[0].RoleName' --output text 2>/dev/null || echo "")
            
            if [[ -n "$ROLE_NAME" ]]; then
                # Check attached policies
                ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
                
                # Check for SSM permissions
                if echo "$ATTACHED_POLICIES" | grep -q "AmazonSSMManagedInstanceCore"; then
                    add_result "SSM Permissions ($instance_id)" "PASS" "SSM managed instance core policy attached" "MEDIUM"
                else
                    add_result "SSM Permissions ($instance_id)" "WARN" "SSM permissions may be missing" "MEDIUM"
                fi
                
                # Check for overly permissive policies
                ADMIN_POLICIES=$(echo "$ATTACHED_POLICIES" | grep -E "(AdministratorAccess|PowerUserAccess)" || echo "")
                if [[ -n "$ADMIN_POLICIES" ]]; then
                    add_result "IAM Permissions ($instance_id)" "FAIL" "Overly permissive IAM policies attached" "HIGH"
                else
                    add_result "IAM Permissions ($instance_id)" "PASS" "No overly permissive policies found" "MEDIUM"
                fi
            fi
        else
            add_result "IAM Instance Profile ($instance_id)" "FAIL" "No IAM instance profile attached" "HIGH"
        fi
    done
fi

# Output results
echo ""
echo "=========================================="
echo "        SECURITY VALIDATION SUMMARY"
echo "=========================================="

case $OUTPUT_FORMAT in
    "json")
        echo "{"
        echo "  \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\","
        echo "  \"environment\": \"$ENVIRONMENT\","
        echo "  \"project\": \"$PROJECT_NAME\","
        echo "  \"region\": \"$AWS_REGION\","
        echo "  \"total_checks\": $TOTAL_CHECKS,"
        echo "  \"failed_checks\": $FAILED_CHECKS,"
        echo "  \"warning_checks\": $WARNING_CHECKS,"
        echo "  \"passed_checks\": $((TOTAL_CHECKS - FAILED_CHECKS - WARNING_CHECKS)),"
        echo "  \"strict_mode\": $STRICT_MODE,"
        echo "  \"results\": ["
        
        for i in "${!VALIDATION_RESULTS[@]}"; do
            echo "    ${VALIDATION_RESULTS[$i]}"
            if [[ $i -lt $((${#VALIDATION_RESULTS[@]} - 1)) ]]; then
                echo ","
            fi
        done
        
        echo "  ]"
        echo "}"
        ;;
    "csv")
        echo "check,status,message,severity"
        for result in "${VALIDATION_RESULTS[@]}"; do
            check=$(echo "$result" | jq -r '.check')
            status=$(echo "$result" | jq -r '.status')
            message=$(echo "$result" | jq -r '.message')
            severity=$(echo "$result" | jq -r '.severity')
            echo "\"$check\",\"$status\",\"$message\",\"$severity\""
        done
        ;;
    *)
        echo "Total Checks: $TOTAL_CHECKS"
        echo "Passed: $((TOTAL_CHECKS - FAILED_CHECKS - WARNING_CHECKS))"
        echo "Warnings: $WARNING_CHECKS"
        echo "Failed: $FAILED_CHECKS"
        
        if [[ "$STRICT_MODE" == "true" ]]; then
            echo "Strict Mode: Enabled (warnings treated as failures)"
        fi
        
        echo ""
        
        if [[ $FAILED_CHECKS -eq 0 ]]; then
            if [[ $WARNING_CHECKS -eq 0 ]]; then
                print_success "🎉 All security validation checks passed!"
            else
                print_warning "⚠️  Security validation completed with $WARNING_CHECKS warnings"
            fi
        else
            print_error "❌ Security validation failed with $FAILED_CHECKS critical issues"
        fi
        ;;
esac

# Exit with appropriate code
if [[ $FAILED_CHECKS -eq 0 ]]; then
    exit 0
else
    exit 1
fi