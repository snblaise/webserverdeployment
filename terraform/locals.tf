# ========================================
# Local Values for Conditional Resources
# ========================================

locals {
  # VPC ID - use created or existing
  vpc_id = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.existing[0].id

  # VPC CIDR - use created or existing
  vpc_cidr = var.create_vpc ? aws_vpc.main[0].cidr_block : data.aws_vpc.existing[0].cidr_block

  # ALB ARN - use created or existing
  alb_arn = var.create_alb ? aws_lb.main[0].arn : data.aws_lb.existing[0].arn

  # ALB DNS - use created or existing
  alb_dns = var.create_alb ? aws_lb.main[0].dns_name : data.aws_lb.existing[0].dns_name

  # Target Group ARN - use created or existing
  target_group_arn = var.create_alb ? aws_lb_target_group.main[0].arn : data.aws_lb_target_group.existing[0].arn

  # WAF Web ACL ARN - use created or existing
  waf_web_acl_arn = var.create_waf ? aws_wafv2_web_acl.main[0].arn : data.aws_wafv2_web_acl.existing[0].arn

  # WAF Web ACL ID - use created or existing
  waf_web_acl_id = var.create_waf ? aws_wafv2_web_acl.main[0].id : data.aws_wafv2_web_acl.existing[0].id

  # Patch Baseline ID - use created or existing
  patch_baseline_id = var.create_patch_baseline ? aws_ssm_patch_baseline.amazon_linux[0].id : data.aws_ssm_patch_baseline.existing[0].id

  # Patch Group Name
  patch_group_name = "${var.project_name}-${var.env}"

  # Public Subnets - use created or existing
  public_subnet_ids = var.create_vpc ? aws_subnet.public[*].id : data.aws_subnets.existing[0].ids

  # Private Subnets - use created or existing  
  private_subnet_ids = var.create_vpc ? aws_subnet.private[*].id : data.aws_subnets.existing_private[0].ids
}