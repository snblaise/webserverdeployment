# ========================================
# Import blocks for existing resources
# ========================================

# Import existing ALB
import {
  to = aws_lb.main
  id = "arn:aws:elasticloadbalancing:us-east-1:948572562675:loadbalancer/app/webserverdeployment-test-alb/badd36f5ed828d13"
}

# Import existing Target Group
import {
  to = aws_lb_target_group.main
  id = "arn:aws:elasticloadbalancing:us-east-1:948572562675:targetgroup/webserverdeployment-test-tg/8b53960e4d6b9cae"
}

# Import existing WAF Web ACL
import {
  to = aws_wafv2_web_acl.main
  id = "aaa0c981-6be0-426d-ba16-c6c5e11bd549/webserverdeployment-test-web-acl/REGIONAL"
}

# Import existing SSM Patch Group
import {
  to = aws_ssm_patch_group.main
  id = "pb-026a6a11e97180c18/webserverdeployment-test"
}