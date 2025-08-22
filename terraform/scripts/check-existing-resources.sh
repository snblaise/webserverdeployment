#!/bin/bash

# Check existing resources and set conditional variables
set -e

echo "Checking for existing resources..."

# Check if ALB exists
if aws elbv2 describe-load-balancers --names "webserverdeployment-${TF_VAR_env}-alb" >/dev/null 2>&1; then
    echo "ALB exists - setting create_alb=false"
    export TF_VAR_create_alb=false
else
    echo "ALB not found - setting create_alb=true"
    export TF_VAR_create_alb=true
fi

# Check if WAF exists
if aws wafv2 list-web-acls --scope REGIONAL --query "WebACLs[?Name=='webserverdeployment-${TF_VAR_env}-web-acl']" --output text | grep -q .; then
    echo "WAF exists - setting create_waf=false"
    export TF_VAR_create_waf=false
else
    echo "WAF not found - setting create_waf=true"
    export TF_VAR_create_waf=true
fi

# Check if Patch Group exists
if aws ssm describe-patch-groups --query "Mappings[?PatchGroup=='webserverdeployment-${TF_VAR_env}']" --output text | grep -q .; then
    echo "Patch Group exists - setting create_patch_baseline=false"
    export TF_VAR_create_patch_baseline=false
else
    echo "Patch Group not found - setting create_patch_baseline=true"
    export TF_VAR_create_patch_baseline=true
fi

# Check if VPC exists
if aws ec2 describe-vpcs --filters "Name=tag:Name,Values=webserverdeployment-${TF_VAR_env}-vpc" --query 'Vpcs[0].VpcId' --output text | grep -q vpc-; then
    echo "VPC exists - setting create_vpc=false"
    export TF_VAR_create_vpc=false
else
    echo "VPC not found - setting create_vpc=true"
    export TF_VAR_create_vpc=true
fi

echo "Resource check completed"