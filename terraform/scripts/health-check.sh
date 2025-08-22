#!/bin/bash

# Health Check Script
# Performs comprehensive health checks on deployed infrastructure
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
ALB_DNS=""
CONTINUOUS=false
CHECK_INTERVAL=30
MAX_CHECKS=10
TIMEOUT=30
VERBOSE=false
OUTPUT_FORMAT="console"
LOG_FILE=""

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

# Function to log with timestamp
log_with_timestamp() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
    
    case $level in
        "INFO")
            print_status "$message"
            ;;
        "SUCCESS")
            print_success "$message"
            ;;
        "WARNING")
            print_warning "$message"
            ;;
        "ERROR")
            print_error "$message"
            ;;
    esac
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Perform comprehensive health checks on deployed AWS infrastructure.

OPTIONS:
    -e, --environment ENV       Target environment (test, staging, prod, preview) [required]
    -p, --project-name NAME     Project name for resource identification [required]
    -r, --region REGION         AWS region [required]
    -d, --alb-dns DNS           ALB DNS name (auto-discovered if not provided)
    -c, --continuous            Run continuous health checks
    -i, --interval SECONDS      Check interval for continuous mode [default: 30]
    -n, --max-checks COUNT      Maximum checks in continuous mode [default: 10]
    -t, --timeout SECONDS       Timeout for individual checks [default: 30]
    -f, --format FORMAT         Output format (console, json, csv) [default: console]
    -l, --log-file FILE         Log file path for continuous monitoring
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    # Single health check
    $0 -e test -p myproject -r us-east-1

    # Continuous monitoring with logging
    $0 -e prod -p myproject -r us-east-1 -c -l health.log

    # JSON output for automation
    $0 -e staging -p myproject -r us-east-1 -f json

    # Custom ALB DNS and timeout
    $0 -e test -p myproject -r us-east-1 -d my-alb-123456.us-east-1.elb.amazonaws.com -t 60

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
        -d|--alb-dns)
            ALB_DNS="$2"
            shift 2
            ;;
        -c|--continuous)
            CONTINUOUS=true
            shift
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -n|--max-checks)
            MAX_CHECKS="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="$2"
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

# Validate output format
case $OUTPUT_FORMAT in
    console|json|csv)
        ;;
    *)
        print_error "Invalid output format: $OUTPUT_FORMAT. Must be one of: console, json, csv"
        exit 1
        ;;
esac

# Check required tools
for tool in aws jq curl; do
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

# Initialize log file if specified
if [[ -n "$LOG_FILE" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "# Health Check Log - Started at $(date)" > "$LOG_FILE"
fi

# Function to discover ALB DNS if not provided
discover_alb_dns() {
    if [[ -z "$ALB_DNS" ]]; then
        log_with_timestamp "INFO" "Discovering ALB DNS name..."
        
        local alb_arn=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME') && contains(LoadBalancerName, '$ENVIRONMENT')].LoadBalancerArn" --output text | head -1)
        
        if [[ -n "$alb_arn" && "$alb_arn" != "None" ]]; then
            ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn" --query 'LoadBalancers[0].DNSName' --output text)
            log_with_timestamp "SUCCESS" "ALB DNS discovered: $ALB_DNS"
        else
            log_with_timestamp "ERROR" "Could not discover ALB DNS name"
            return 1
        fi
    fi
}

# Function to perform ALB health check
check_alb_health() {
    local start_time=$(date +%s)
    local response_code=""
    local response_time=""
    local error_message=""
    
    if [[ -n "$ALB_DNS" ]]; then
        # Test HTTP connectivity
        local curl_output=$(curl -s -w "%{http_code},%{time_total}" --max-time "$TIMEOUT" "http://$ALB_DNS" 2>&1 || echo "000,0")
        
        if [[ "$curl_output" == *","* ]]; then
            response_code=$(echo "$curl_output" | tail -1 | cut -d',' -f1)
            response_time=$(echo "$curl_output" | tail -1 | cut -d',' -f2)
        else
            response_code="000"
            response_time="0"
            error_message="$curl_output"
        fi
        
        local end_time=$(date +%s)
        local check_duration=$((end_time - start_time))
        
        # Determine health status
        local status="HEALTHY"
        local message="HTTP $response_code, ${response_time}s response time"
        
        if [[ "$response_code" -ge 200 && "$response_code" -lt 400 ]]; then
            status="HEALTHY"
        elif [[ "$response_code" -ge 400 && "$response_code" -lt 500 ]]; then
            status="DEGRADED"
            message="Client error: $message"
        elif [[ "$response_code" -ge 500 ]]; then
            status="UNHEALTHY"
            message="Server error: $message"
        else
            status="UNHEALTHY"
            message="Connection failed: ${error_message:-Unknown error}"
        fi
        
        echo "$status|$response_code|$response_time|$check_duration|$message"
    else
        echo "UNKNOWN|000|0|0|ALB DNS not available"
    fi
}

# Function to check EC2 instance health
check_ec2_health() {
    local tag_filters="Name=tag:Project,Values=$PROJECT_NAME Name=tag:Environment,Values=$ENVIRONMENT"
    local instance_ids=$(aws ec2 describe-instances --filters $tag_filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId' --output text)
    
    local healthy_count=0
    local total_count=0
    local unhealthy_instances=()
    
    for instance_id in $instance_ids; do
        total_count=$((total_count + 1))
        
        # Check instance status
        local instance_status=$(aws ec2 describe-instance-status --instance-ids "$instance_id" --query 'InstanceStatuses[0].InstanceStatus.Status' --output text 2>/dev/null || echo "unknown")
        local system_status=$(aws ec2 describe-instance-status --instance-ids "$instance_id" --query 'InstanceStatuses[0].SystemStatus.Status' --output text 2>/dev/null || echo "unknown")
        
        if [[ "$instance_status" == "ok" && "$system_status" == "ok" ]]; then
            healthy_count=$((healthy_count + 1))
        else
            unhealthy_instances+=("$instance_id:$instance_status/$system_status")
        fi
    done
    
    local status="HEALTHY"
    local message="$healthy_count/$total_count instances healthy"
    
    if [[ $total_count -eq 0 ]]; then
        status="UNKNOWN"
        message="No instances found"
    elif [[ $healthy_count -eq 0 ]]; then
        status="UNHEALTHY"
        message="All instances unhealthy"
    elif [[ $healthy_count -lt $total_count ]]; then
        status="DEGRADED"
        message="$healthy_count/$total_count instances healthy"
    fi
    
    echo "$status|$healthy_count|$total_count|${unhealthy_instances[*]}|$message"
}

# Function to check CloudWatch alarms
check_cloudwatch_alarms() {
    local alarm_prefix="${PROJECT_NAME}-${ENVIRONMENT}"
    local alarms=$(aws cloudwatch describe-alarms --alarm-name-prefix "$alarm_prefix" --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason}' --output json 2>/dev/null || echo "[]")
    
    local total_alarms=$(echo "$alarms" | jq length)
    local ok_alarms=$(echo "$alarms" | jq '[.[] | select(.State == "OK")] | length')
    local alarm_alarms=$(echo "$alarms" | jq '[.[] | select(.State == "ALARM")] | length')
    local insufficient_data=$(echo "$alarms" | jq '[.[] | select(.State == "INSUFFICIENT_DATA")] | length')
    
    local status="HEALTHY"
    local message="$ok_alarms/$total_alarms alarms OK"
    
    if [[ $total_alarms -eq 0 ]]; then
        status="UNKNOWN"
        message="No alarms found"
    elif [[ $alarm_alarms -gt 0 ]]; then
        status="UNHEALTHY"
        message="$alarm_alarms alarms in ALARM state"
    elif [[ $insufficient_data -gt 0 ]]; then
        status="DEGRADED"
        message="$insufficient_data alarms with insufficient data"
    fi
    
    echo "$status|$ok_alarms|$alarm_alarms|$insufficient_data|$message"
}

# Function to check target group health
check_target_group_health() {
    if [[ -z "$ALB_DNS" ]]; then
        echo "UNKNOWN|0|0|0|ALB not available"
        return
    fi
    
    local alb_arn=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='$ALB_DNS'].LoadBalancerArn" --output text)
    
    if [[ -z "$alb_arn" || "$alb_arn" == "None" ]]; then
        echo "UNKNOWN|0|0|0|ALB not found"
        return
    fi
    
    local target_groups=$(aws elbv2 describe-target-groups --load-balancer-arn "$alb_arn" --query 'TargetGroups[].TargetGroupArn' --output text)
    
    local total_targets=0
    local healthy_targets=0
    local unhealthy_targets=0
    
    for tg_arn in $target_groups; do
        local tg_health=$(aws elbv2 describe-target-health --target-group-arn "$tg_arn" --query 'TargetHealthDescriptions[].TargetHealth.State' --output text)
        
        for state in $tg_health; do
            total_targets=$((total_targets + 1))
            if [[ "$state" == "healthy" ]]; then
                healthy_targets=$((healthy_targets + 1))
            else
                unhealthy_targets=$((unhealthy_targets + 1))
            fi
        done
    done
    
    local status="HEALTHY"
    local message="$healthy_targets/$total_targets targets healthy"
    
    if [[ $total_targets -eq 0 ]]; then
        status="UNKNOWN"
        message="No targets found"
    elif [[ $healthy_targets -eq 0 ]]; then
        status="UNHEALTHY"
        message="All targets unhealthy"
    elif [[ $unhealthy_targets -gt 0 ]]; then
        status="DEGRADED"
        message="$healthy_targets/$total_targets targets healthy"
    fi
    
    echo "$status|$healthy_targets|$unhealthy_targets|$total_targets|$message"
}

# Function to perform comprehensive health check
perform_health_check() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local check_start=$(date +%s)
    
    # Discover ALB DNS if needed
    if ! discover_alb_dns; then
        return 1
    fi
    
    # Perform individual health checks
    local alb_result=$(check_alb_health)
    local ec2_result=$(check_ec2_health)
    local alarm_result=$(check_cloudwatch_alarms)
    local target_result=$(check_target_group_health)
    
    local check_end=$(date +%s)
    local total_duration=$((check_end - check_start))
    
    # Parse results
    IFS='|' read -r alb_status alb_code alb_time alb_duration alb_message <<< "$alb_result"
    IFS='|' read -r ec2_status ec2_healthy ec2_total ec2_unhealthy ec2_message <<< "$ec2_result"
    IFS='|' read -r alarm_status alarm_ok alarm_alarm alarm_insufficient alarm_message <<< "$alarm_result"
    IFS='|' read -r target_status target_healthy target_unhealthy target_total target_message <<< "$target_result"
    
    # Determine overall health
    local overall_status="HEALTHY"
    if [[ "$alb_status" == "UNHEALTHY" || "$ec2_status" == "UNHEALTHY" || "$alarm_status" == "UNHEALTHY" || "$target_status" == "UNHEALTHY" ]]; then
        overall_status="UNHEALTHY"
    elif [[ "$alb_status" == "DEGRADED" || "$ec2_status" == "DEGRADED" || "$alarm_status" == "DEGRADED" || "$target_status" == "DEGRADED" ]]; then
        overall_status="DEGRADED"
    elif [[ "$alb_status" == "UNKNOWN" || "$ec2_status" == "UNKNOWN" || "$alarm_status" == "UNKNOWN" || "$target_status" == "UNKNOWN" ]]; then
        overall_status="UNKNOWN"
    fi
    
    # Output results based on format
    case $OUTPUT_FORMAT in
        "json")
            cat << EOF
{
  "timestamp": "$timestamp",
  "environment": "$ENVIRONMENT",
  "project": "$PROJECT_NAME",
  "region": "$AWS_REGION",
  "overall_status": "$overall_status",
  "check_duration": $total_duration,
  "alb": {
    "status": "$alb_status",
    "dns": "$ALB_DNS",
    "response_code": "$alb_code",
    "response_time": "$alb_time",
    "message": "$alb_message"
  },
  "ec2": {
    "status": "$ec2_status",
    "healthy_instances": "$ec2_healthy",
    "total_instances": "$ec2_total",
    "message": "$ec2_message"
  },
  "cloudwatch": {
    "status": "$alarm_status",
    "ok_alarms": "$alarm_ok",
    "alarm_alarms": "$alarm_alarm",
    "insufficient_data": "$alarm_insufficient",
    "message": "$alarm_message"
  },
  "targets": {
    "status": "$target_status",
    "healthy_targets": "$target_healthy",
    "unhealthy_targets": "$target_unhealthy",
    "total_targets": "$target_total",
    "message": "$target_message"
  }
}
EOF
            ;;
        "csv")
            if [[ ! -f "/tmp/health_check_header_printed" ]]; then
                echo "timestamp,environment,project,region,overall_status,check_duration,alb_status,alb_code,alb_time,ec2_status,ec2_healthy,ec2_total,alarm_status,alarm_ok,alarm_alarm,target_status,target_healthy,target_total"
                touch "/tmp/health_check_header_printed"
            fi
            echo "$timestamp,$ENVIRONMENT,$PROJECT_NAME,$AWS_REGION,$overall_status,$total_duration,$alb_status,$alb_code,$alb_time,$ec2_status,$ec2_healthy,$ec2_total,$alarm_status,$alarm_ok,$alarm_alarm,$target_status,$target_healthy,$target_total"
            ;;
        *)
            # Console output
            echo ""
            echo "=========================================="
            echo "    HEALTH CHECK - $timestamp"
            echo "=========================================="
            echo "Environment: $ENVIRONMENT"
            echo "Project: $PROJECT_NAME"
            echo "Region: $AWS_REGION"
            echo "Overall Status: $overall_status"
            echo "Check Duration: ${total_duration}s"
            echo ""
            
            case $overall_status in
                "HEALTHY")
                    print_success "🟢 Overall Status: HEALTHY"
                    ;;
                "DEGRADED")
                    print_warning "🟡 Overall Status: DEGRADED"
                    ;;
                "UNHEALTHY")
                    print_error "🔴 Overall Status: UNHEALTHY"
                    ;;
                *)
                    print_warning "⚪ Overall Status: UNKNOWN"
                    ;;
            esac
            
            echo ""
            echo "Component Health:"
            echo "  ALB:        $alb_status - $alb_message"
            echo "  EC2:        $ec2_status - $ec2_message"
            echo "  CloudWatch: $alarm_status - $alarm_message"
            echo "  Targets:    $target_status - $target_message"
            
            if [[ "$VERBOSE" == "true" ]]; then
                echo ""
                echo "Detailed Information:"
                echo "  ALB DNS:           $ALB_DNS"
                echo "  Response Code:     $alb_code"
                echo "  Response Time:     ${alb_time}s"
                echo "  Healthy Instances: $ec2_healthy/$ec2_total"
                echo "  OK Alarms:         $alarm_ok"
                echo "  Alarm Alarms:      $alarm_alarm"
                echo "  Healthy Targets:   $target_healthy/$target_total"
            fi
            ;;
    esac
    
    # Log to file if specified
    if [[ -n "$LOG_FILE" ]]; then
        echo "$timestamp,$overall_status,$alb_status,$ec2_status,$alarm_status,$target_status,$total_duration" >> "$LOG_FILE"
    fi
    
    # Return appropriate exit code
    case $overall_status in
        "HEALTHY")
            return 0
            ;;
        "DEGRADED")
            return 1
            ;;
        "UNHEALTHY")
            return 2
            ;;
        *)
            return 3
            ;;
    esac
}

# Main execution
if [[ "$CONTINUOUS" == "true" ]]; then
    log_with_timestamp "INFO" "Starting continuous health monitoring (max $MAX_CHECKS checks, ${CHECK_INTERVAL}s interval)"
    
    check_count=0
    while [[ $check_count -lt $MAX_CHECKS ]]; do
        check_count=$((check_count + 1))
        
        log_with_timestamp "INFO" "Health check $check_count/$MAX_CHECKS"
        
        if perform_health_check; then
            log_with_timestamp "SUCCESS" "Health check passed"
        else
            exit_code=$?
            case $exit_code in
                1)
                    log_with_timestamp "WARNING" "Health check shows degraded status"
                    ;;
                2)
                    log_with_timestamp "ERROR" "Health check shows unhealthy status"
                    ;;
                *)
                    log_with_timestamp "WARNING" "Health check status unknown"
                    ;;
            esac
        fi
        
        if [[ $check_count -lt $MAX_CHECKS ]]; then
            sleep $CHECK_INTERVAL
        fi
    done
    
    log_with_timestamp "INFO" "Continuous monitoring completed"
else
    # Single health check
    perform_health_check
fi