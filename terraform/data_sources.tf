# ========================================
# Data Sources for Existing Resources
# ========================================

# Existing VPC (when create_vpc = false)
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-${var.env}-vpc"]
  }
}

# Existing public subnets (when create_vpc = false)
data "aws_subnets" "existing" {
  count = var.create_vpc ? 0 : 1
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}

# Existing private subnets (when create_vpc = false)
data "aws_subnets" "existing_private" {
  count = var.create_vpc ? 0 : 1
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["Private"]
  }
}

# Existing ALB (when create_alb = false)
data "aws_lb" "existing" {
  count = var.create_alb ? 0 : 1
  name  = "${var.project_name}-${var.env}-alb"
}

# Existing Target Group (when create_alb = false)
data "aws_lb_target_group" "existing" {
  count = var.create_alb ? 0 : 1
  name  = "${var.project_name}-${var.env}-tg"
}

# Existing WAF Web ACL (when create_waf = false)
data "aws_wafv2_web_acl" "existing" {
  count = var.create_waf ? 0 : 1
  name  = "${var.project_name}-${var.env}-web-acl"
  scope = "REGIONAL"
}

# Existing SSM Patch Baseline (when create_patch_baseline = false)
data "aws_ssm_patch_baseline" "existing" {
  count = var.create_patch_baseline ? 0 : 1
  
  owner            = "Self"
  name_prefix      = "${var.project_name}-${var.env}"
  operating_system = "AMAZON_LINUX_2023"
}