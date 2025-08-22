#!/bin/bash

# Import existing resources script
set -e

echo "Importing existing resources..."

# Get resource identifiers
ALB_ARN=$(aws elbv2 describe-load-balancers --names webserverdeployment-test-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
TG_ARN=$(aws elbv2 describe-target-groups --names webserverdeployment-test-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")
WAF_ID=$(aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[?Name==`webserverdeployment-test-web-acl`].Id' --output text 2>/dev/null || echo "")
PATCH_BASELINE_ID=$(aws ssm describe-patch-groups --query 'Mappings[?PatchGroup==`webserverdeployment-test`].BaselineIdentity.BaselineId' --output text 2>/dev/null || echo "")

# Import ALB if exists
if [ ! -z "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    echo "Importing ALB: $ALB_ARN"
    terraform import aws_lb.main "$ALB_ARN" || echo "ALB import failed or already imported"
fi

# Import Target Group if exists
if [ ! -z "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
    echo "Importing Target Group: $TG_ARN"
    terraform import aws_lb_target_group.main "$TG_ARN" || echo "Target Group import failed or already imported"
fi

# Import WAF if exists
if [ ! -z "$WAF_ID" ] && [ "$WAF_ID" != "None" ]; then
    echo "Importing WAF: $WAF_ID"
    terraform import aws_wafv2_web_acl.main "$WAF_ID/webserverdeployment-test-web-acl/REGIONAL" || echo "WAF import failed or already imported"
fi

# Import SSM Patch Group if exists
if [ ! -z "$PATCH_BASELINE_ID" ] && [ "$PATCH_BASELINE_ID" != "None" ]; then
    echo "Importing SSM Patch Group: $PATCH_BASELINE_ID"
    terraform import aws_ssm_patch_group.main "$PATCH_BASELINE_ID/webserverdeployment-test" || echo "Patch Group import failed or already imported"
fi

echo "Import process completed"