#!/bin/bash

# Enhanced Import and Refresh Script
# This script imports existing AWS resources into Terraform state to prevent recreation
# It should be run before applying Terraform changes to existing infrastructure

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

# Default values
ENVIRONMENT="${TF_VAR_env:-test}"
PROJECT_NAME="${TF_VAR_project_name:-webserverdeployment}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
DRY_RUN=false
VERBOSE=false
FORCE_IMPORT=false
SKIP_REFRESH=false

# Import tracking
IMPORT_SUCCESS=0
IMPORT_FAILED=0
IMPORT_SKIPPED=0

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Import existing AWS resources into Terraform state to prevent recreation.

OPTIONS:
    -e, --environment ENV       Target environment [default: $ENVIRONMENT]
    -p, --project-name NAME     Project name [default: $PROJECT_NAME]
    -r, --region REGION         AWS region [default: $AWS_REGION]
    -d, --dry-run               Show what would be imported without importing
    -f, --force                 Force import even if resource exists in state
    --skip-refresh              Skip terraform refresh after imports
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    # Import resources for test environment
    $0 -e test -p myproject

    # Dry run to see what would be imported
    $0 -e prod -p myproject --dry-run

    # Force import with verbose output
    $0 -e staging -p myproject --force -v

ENVIRONMENT VARIABLES:
    TF_VAR_env                  Environment name
    TF_VAR_project_name         Project name
    AWS_DEFAULT_REGION          AWS region

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
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE_IMPORT=true
            shift
            ;;
        --skip-refresh)
            SKIP_REFRESH=true
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

print_status "Starting enhanced import process for environment: $ENVIRONMENT"
print_status "Project: $PROJECT_NAME, Region: $AWS_REGION"

# Check prerequisites
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed or not in PATH"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed or not in PATH"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    print_error "jq is not installed or not in PATH"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    exit 1
fi

# Function to check if resource exists in AWS
resource_exists() {
    local resource_type="$1"
    local resource_id="$2"
    
    case $resource_type in
        "vpc")
            aws ec2 describe-vpcs --vpc-ids "$resource_id" &> /dev/null
            ;;
        "subnet")
            aws ec2 describe-subnets --subnet-ids "$resource_id" &> /dev/null
            ;;
        "security_group")
            aws ec2 describe-security-groups --group-ids "$resource_id" &> /dev/null
            ;;
        "instance")
            aws ec2 describe-instances --instance-ids "$resource_id" &> /dev/null
            ;;
        "alb")
            aws elbv2 describe-load-balancers --load-balancer-arns "$resource_id" &> /dev/null
            ;;
        "target_group")
            aws elbv2 describe-target-groups --target-group-arns "$resource_id" &> /dev/null
            ;;
        "igw")
            aws ec2 describe-internet-gateways --internet-gateway-ids "$resource_id" &> /dev/null
            ;;
        "nat_gateway")
            aws ec2 describe-nat-gateways --nat-gateway-ids "$resource_id" &> /dev/null
            ;;
        "route_table")
            aws ec2 describe-route-tables --route-table-ids "$resource_id" &> /dev/null
            ;;
        "waf_web_acl")
            local waf_id=$(echo "$resource_id" | cut -d'/' -f1)
            aws wafv2 get-web-acl --scope REGIONAL --id "$waf_id" --name "$(echo "$resource_id" | cut -d'/' -f2)" &> /dev/null
            ;;
        "sns_topic")
            aws sns get-topic-attributes --topic-arn "$resource_id" &> /dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if resource exists in Terraform state
resource_in_state() {
    local tf_address="$1"
    terraform state show "$tf_address" &> /dev/null
}

# Function to import resource with enhanced error handling
import_resource() {
    local tf_address="$1"
    local resource_id="$2"
    local resource_type="$3"
    local description="${4:-$tf_address}"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "[DRY RUN] Would import $description ($tf_address) with ID: $resource_id"
        return 0
    fi
    
    # Check if resource already exists in state
    if resource_in_state "$tf_address"; then
        if [ "$FORCE_IMPORT" = true ]; then
            print_warning "Resource $tf_address exists in state, but force import enabled"
            print_status "Removing from state first: $tf_address"
            terraform state rm "$tf_address" &> /dev/null || true
        else
            print_warning "Resource $tf_address already exists in state, skipping import"
            IMPORT_SKIPPED=$((IMPORT_SKIPPED + 1))
            return 0
        fi
    fi
    
    # Check if resource exists in AWS
    if ! resource_exists "$resource_type" "$resource_id"; then
        print_warning "Resource $resource_id does not exist in AWS, skipping import"
        IMPORT_SKIPPED=$((IMPORT_SKIPPED + 1))
        return 0
    fi
    
    print_status "Importing $description ($tf_address) with ID: $resource_id"
    
    # Attempt import with timeout and retry
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            print_status "Retry attempt $attempt/$max_attempts for $tf_address"
            sleep 2
        fi
        
        if timeout 60 terraform import "$tf_address" "$resource_id" 2>/dev/null; then
            print_success "Successfully imported $description"
            IMPORT_SUCCESS=$((IMPORT_SUCCESS + 1))
            return 0
        else
            if [ $attempt -eq $max_attempts ]; then
                print_error "Failed to import $description after $max_attempts attempts"
                IMPORT_FAILED=$((IMPORT_FAILED + 1))
                return 1
            fi
        fi
        
        attempt=$((attempt + 1))
    done
}

# Function to discover and import VPC resources
import_vpc_resources() {
    local tag_filters="Name=tag:Project,Values=$PROJECT_NAME Name=tag:Environment,Values=$ENVIRONMENT"
    
    print_status "🔍 Discovering VPC resources..."
    
    # Discover VPC
    local vpc_id=$(aws ec2 describe-vpcs --filters $tag_filters --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    if [ "$vpc_id" != "None" ] && [ -n "$vpc_id" ]; then
        print_status "Found VPC: $vpc_id"
        import_resource "aws_vpc.main" "$vpc_id" "vpc" "Main VPC"
        
        # Import Internet Gateway
        local igw_id=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "None")
        if [ "$igw_id" != "None" ] && [ -n "$igw_id" ]; then
            import_resource "aws_internet_gateway.main" "$igw_id" "igw" "Internet Gateway"
        fi
        
        # Import subnets
        import_subnets "$vpc_id"
        
        # Import route tables
        import_route_tables "$vpc_id"
        
        # Import NAT Gateways
        import_nat_gateways "$vpc_id"
        
    else
        print_warning "No VPC found with tags Project=$PROJECT_NAME, Environment=$ENVIRONMENT"
    fi
}

# Function to import subnets
import_subnets() {
    local vpc_id="$1"
    
    print_status "🔍 Discovering subnets in VPC: $vpc_id"
    
    # Get public subnets
    local public_subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Type,Values=public" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    
    if [ -n "$public_subnets" ]; then
        local subnet_index=0
        for subnet_id in $public_subnets; do
            local az=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --query 'Subnets[0].AvailabilityZone' --output text 2>/dev/null || echo "unknown")
            import_resource "aws_subnet.public[$subnet_index]" "$subnet_id" "subnet" "Public Subnet ($az)"
            subnet_index=$((subnet_index + 1))
        done
    fi
    
    # Get private subnets
    local private_subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Type,Values=private" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    
    if [ -n "$private_subnets" ]; then
        local subnet_index=0
        for subnet_id in $private_subnets; do
            local az=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --query 'Subnets[0].AvailabilityZone' --output text 2>/dev/null || echo "unknown")
            import_resource "aws_subnet.private[$subnet_index]" "$subnet_id" "subnet" "Private Subnet ($az)"
            subnet_index=$((subnet_index + 1))
        done
    fi
}

# Function to import route tables
import_route_tables() {
    local vpc_id="$1"
    
    print_status "🔍 Discovering route tables in VPC: $vpc_id"
    
    # Get route tables with tags
    local route_tables=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Project,Values=$PROJECT_NAME" --query 'RouteTables[].RouteTableId' --output text 2>/dev/null || echo "")
    
    if [ -n "$route_tables" ]; then
        for rt_id in $route_tables; do
            local rt_name=$(aws ec2 describe-route-tables --route-table-ids "$rt_id" --query 'RouteTables[0].Tags[?Key==`Name`].Value' --output text 2>/dev/null || echo "unknown")
            
            # Determine route table type and import accordingly
            if [[ "$rt_name" == *"public"* ]]; then
                import_resource "aws_route_table.public[0]" "$rt_id" "route_table" "Public Route Table"
            elif [[ "$rt_name" == *"private"* ]]; then
                import_resource "aws_route_table.private[0]" "$rt_id" "route_table" "Private Route Table"
            fi
        done
    fi
}

# Function to import NAT Gateways
import_nat_gateways() {
    local vpc_id="$1"
    
    print_status "🔍 Discovering NAT Gateways in VPC: $vpc_id"
    
    local nat_gateways=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" "Name=state,Values=available" --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null || echo "")
    
    if [ -n "$nat_gateways" ]; then
        local nat_index=0
        for nat_id in $nat_gateways; do
            import_resource "aws_nat_gateway.main[$nat_index]" "$nat_id" "nat_gateway" "NAT Gateway"
            nat_index=$((nat_index + 1))
        done
    fi
}

# Function to import security groups
import_security_groups() {
    local tag_filters="Name=tag:Project,Values=$PROJECT_NAME Name=tag:Environment,Values=$ENVIRONMENT"
    
    print_status "🔍 Discovering security groups..."
    
    local security_groups=$(aws ec2 describe-security-groups --filters $tag_filters --query 'SecurityGroups[].[GroupId,GroupName]' --output text 2>/dev/null || echo "")
    
    if [ -n "$security_groups" ]; then
        while IFS=$'\t' read -r sg_id sg_name; do
            if [ -n "$sg_id" ] && [ -n "$sg_name" ]; then
                # Map security group names to Terraform resources
                case $sg_name in
                    *alb*|*ALB*)
                        import_resource "aws_security_group.alb" "$sg_id" "security_group" "ALB Security Group"
                        ;;
                    *ec2*|*EC2*|*instance*|*web*)
                        import_resource "aws_security_group.ec2" "$sg_id" "security_group" "EC2 Security Group"
                        ;;
                    *)
                        print_warning "Unknown security group pattern: $sg_name, attempting generic import"
                        import_resource "aws_security_group.${sg_name//[^a-zA-Z0-9]/_}" "$sg_id" "security_group" "Security Group ($sg_name)"
                        ;;
                esac
            fi
        done <<< "$security_groups"
    fi
}

# Function to import EC2 instances
import_ec2_instances() {
    local tag_filters="Name=tag:Project,Values=$PROJECT_NAME Name=tag:Environment,Values=$ENVIRONMENT"
    
    print_status "🔍 Discovering EC2 instances..."
    
    local instances=$(aws ec2 describe-instances --filters $tag_filters "Name=instance-state-name,Values=running,stopped,stopping,pending" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output text 2>/dev/null || echo "")
    
    if [ -n "$instances" ]; then
        local instance_index=0
        while IFS=$'\t' read -r instance_id instance_name; do
            if [ -n "$instance_id" ]; then
                local name_desc="${instance_name:-Instance $instance_index}"
                import_resource "aws_instance.web[$instance_index]" "$instance_id" "instance" "EC2 Instance ($name_desc)"
                instance_index=$((instance_index + 1))
            fi
        done <<< "$instances"
    fi
}

# Function to import load balancer resources
import_load_balancer_resources() {
    print_status "🔍 Discovering load balancer resources..."
    
    # Find ALB by name pattern
    local alb_arn=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME') && contains(LoadBalancerName, '$ENVIRONMENT')].LoadBalancerArn" --output text 2>/dev/null | head -1 || echo "")
    
    if [ -n "$alb_arn" ] && [ "$alb_arn" != "None" ]; then
        local alb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn" --query 'LoadBalancers[0].LoadBalancerName' --output text 2>/dev/null || echo "unknown")
        import_resource "aws_lb.main" "$alb_arn" "alb" "Application Load Balancer ($alb_name)"
        
        # Import target groups
        local target_groups=$(aws elbv2 describe-target-groups --load-balancer-arn "$alb_arn" --query 'TargetGroups[].TargetGroupArn' --output text 2>/dev/null || echo "")
        
        if [ -n "$target_groups" ]; then
            local tg_index=0
            for tg_arn in $target_groups; do
                local tg_name=$(aws elbv2 describe-target-groups --target-group-arns "$tg_arn" --query 'TargetGroups[0].TargetGroupName' --output text 2>/dev/null || echo "unknown")
                import_resource "aws_lb_target_group.main[$tg_index]" "$tg_arn" "target_group" "Target Group ($tg_name)"
                tg_index=$((tg_index + 1))
            done
        fi
        
        # Import listeners
        local listeners=$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --query 'Listeners[].ListenerArn' --output text 2>/dev/null || echo "")
        
        if [ -n "$listeners" ]; then
            local listener_index=0
            for listener_arn in $listeners; do
                local port=$(aws elbv2 describe-listeners --listener-arns "$listener_arn" --query 'Listeners[0].Port' --output text 2>/dev/null || echo "unknown")
                import_resource "aws_lb_listener.main[$listener_index]" "$listener_arn" "listener" "Listener (Port $port)"
                listener_index=$((listener_index + 1))
            done
        fi
    fi
}

# Function to import WAF resources
import_waf_resources() {
    print_status "🔍 Discovering WAF resources..."
    
    local waf_name="${PROJECT_NAME}-${ENVIRONMENT}-waf"
    local waf_id=$(aws wafv2 list-web-acls --scope REGIONAL --query "WebACLs[?Name=='$waf_name'].Id" --output text 2>/dev/null || echo "")
    
    if [ -n "$waf_id" ] && [ "$waf_id" != "None" ]; then
        import_resource "aws_wafv2_web_acl.main" "$waf_id/$waf_name/REGIONAL" "waf_web_acl" "WAF Web ACL ($waf_name)"
    fi
}

# Function to import SNS resources
import_sns_resources() {
    print_status "🔍 Discovering SNS resources..."
    
    local sns_topic_name="${PROJECT_NAME}-${ENVIRONMENT}-alerts"
    local sns_topic_arn=$(aws sns list-topics --query "Topics[?contains(TopicArn, '$sns_topic_name')].TopicArn" --output text 2>/dev/null || echo "")
    
    if [ -n "$sns_topic_arn" ] && [ "$sns_topic_arn" != "None" ]; then
        import_resource "aws_sns_topic.alerts" "$sns_topic_arn" "sns_topic" "SNS Topic ($sns_topic_name)"
    fi
}

# Function to show import summary
show_import_summary() {
    echo ""
    echo "=========================================="
    echo "           IMPORT SUMMARY"
    echo "=========================================="
    echo "✅ Successful imports: $IMPORT_SUCCESS"
    echo "❌ Failed imports: $IMPORT_FAILED"
    echo "⏭️  Skipped imports: $IMPORT_SKIPPED"
    echo "📊 Total operations: $((IMPORT_SUCCESS + IMPORT_FAILED + IMPORT_SKIPPED))"
    
    if [ $IMPORT_FAILED -gt 0 ]; then
        echo ""
        print_warning "$IMPORT_FAILED imports failed. Check the output above for details."
        echo "This may be normal for new deployments or if resources don't exist yet."
    fi
    
    if [ $IMPORT_SUCCESS -gt 0 ]; then
        echo ""
        print_success "$IMPORT_SUCCESS resources imported successfully!"
    fi
}

# Main execution
print_status "Starting enhanced resource discovery and import process..."

if [ "$DRY_RUN" = true ]; then
    print_warning "🔍 DRY RUN MODE: No actual imports will be performed"
fi

if [ "$FORCE_IMPORT" = true ]; then
    print_warning "⚠️  FORCE MODE: Existing state entries will be replaced"
fi

# Import resources by category
import_vpc_resources
import_security_groups
import_ec2_instances
import_load_balancer_resources
import_waf_resources
import_sns_resources

# Refresh Terraform state
if [ "$DRY_RUN" = false ] && [ "$SKIP_REFRESH" = false ] && [ $IMPORT_SUCCESS -gt 0 ]; then
    print_status "🔄 Refreshing Terraform state..."
    if terraform refresh -input=false; then
        print_success "Terraform state refreshed successfully"
    else
        print_error "Failed to refresh Terraform state"
        exit 1
    fi
fi

# Show summary
show_import_summary

if [ "$DRY_RUN" = true ]; then
    print_status "💡 Run without --dry-run flag to perform actual imports"
fi

# Exit with appropriate code
if [ $IMPORT_FAILED -gt 0 ] && [ $IMPORT_SUCCESS -eq 0 ]; then
    exit 1
else
    exit 0
fi