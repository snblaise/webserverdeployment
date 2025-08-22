#!/bin/bash

# Import existing resources and refresh state
set -e

echo "Importing existing resources..."

# Import ALB if exists
ALB_ARN=$(aws elbv2 describe-load-balancers --names "webserverdeployment-${TF_VAR_env}-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
if [ ! -z "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    echo "Importing ALB: $ALB_ARN"
    terraform import 'aws_lb.main[0]' "$ALB_ARN" || echo "ALB already imported"
fi

# Import Target Group if exists
TG_ARN=$(aws elbv2 describe-target-groups --names "webserverdeployment-${TF_VAR_env}-tg" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")
if [ ! -z "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
    echo "Importing Target Group: $TG_ARN"
    terraform import 'aws_lb_target_group.main[0]' "$TG_ARN" || echo "Target Group already imported"
fi

# Import WAF if exists
WAF_ID=$(aws wafv2 list-web-acls --scope REGIONAL --query "WebACLs[?Name=='webserverdeployment-${TF_VAR_env}-web-acl'].Id" --output text 2>/dev/null || echo "")
if [ ! -z "$WAF_ID" ] && [ "$WAF_ID" != "None" ]; then
    echo "Importing WAF: $WAF_ID"
    terraform import 'aws_wafv2_web_acl.main[0]' "$WAF_ID/webserverdeployment-${TF_VAR_env}-web-acl/REGIONAL" || echo "WAF already imported"
fi

# Import Patch Group if exists
PATCH_BASELINE_ID=$(aws ssm describe-patch-groups --query "Mappings[?PatchGroup=='webserverdeployment-${TF_VAR_env}'].BaselineIdentity.BaselineId" --output text 2>/dev/null || echo "")
if [ ! -z "$PATCH_BASELINE_ID" ] && [ "$PATCH_BASELINE_ID" != "None" ]; then
    echo "Importing Patch Group: $PATCH_BASELINE_ID"
    terraform import 'aws_ssm_patch_group.main[0]' "$PATCH_BASELINE_ID/webserverdeployment-${TF_VAR_env}" || echo "Patch Group already imported"
fi

echo "Running terraform refresh to sync state..."
terraform apply -refresh-only -auto-approve

echo "Import and refresh completed"