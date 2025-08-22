#!/bin/bash

# Check existing resources and set conditional variables
set -e

echo "Checking for existing resources..."

# Check if ALB exists
if aws elbv2 describe-load-balancers --names "webserverdeployment-${TF_VAR_env}-alb" >/dev/null 2>&1; then
    echo "ALB exists - setting create_alb=false"
    echo 'export TF_VAR_create_alb=false' >> $GITHUB_ENV
else
    echo "ALB not found - setting create_alb=true"
    echo 'export TF_VAR_create_alb=true' >> $GITHUB_ENV
fi

# Check if WAF exists
if aws wafv2 list-web-acls --scope REGIONAL --query "WebACLs[?Name=='webserverdeployment-${TF_VAR_env}-web-acl']" --output text | grep -q .; then
    echo "WAF exists - setting create_waf=false"
    echo 'export TF_VAR_create_waf=false' >> $GITHUB_ENV
else
    echo "WAF not found - setting create_waf=true"
    echo 'export TF_VAR_create_waf=true' >> $GITHUB_ENV
fi

# Check if Patch Group exists
if aws ssm describe-patch-groups --query "Mappings[?PatchGroup=='webserverdeployment-${TF_VAR_env}']" --output text | grep -q .; then
    echo "Patch Group exists - setting create_patch_baseline=false"
    echo 'export TF_VAR_create_patch_baseline=false' >> $GITHUB_ENV
else
    echo "Patch Group not found - setting create_patch_baseline=true"
    echo 'export TF_VAR_create_patch_baseline=true' >> $GITHUB_ENV
fi

# Check if VPC exists
if aws ec2 describe-vpcs --filters "Name=tag:Name,Values=webserverdeployment-${TF_VAR_env}-vpc" --query 'Vpcs[0].VpcId' --output text | grep -q vpc-; then
    echo "VPC exists - setting create_vpc=false"
    echo 'export TF_VAR_create_vpc=false' >> $GITHUB_ENV
else
    echo "VPC not found - setting create_vpc=true"
    echo 'export TF_VAR_create_vpc=true' >> $GITHUB_ENV
fi

echo "Resource check completed"