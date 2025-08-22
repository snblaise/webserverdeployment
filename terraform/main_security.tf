# ========================================
# IAM Roles and Policies
# ========================================

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name_prefix = "${var.project_name}-${var.env}-ec2-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-ec2-role"
  })
}

# Instance profile for EC2 role
resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${var.project_name}-${var.env}-ec2-profile-"
  role        = aws_iam_role.ec2_role.name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-ec2-profile"
  })
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AWS managed policy for CloudWatch Agent
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent_server_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom IAM policy for CloudWatch metrics and logs
resource "aws_iam_policy" "ec2_cloudwatch_custom" {
  name_prefix = "${var.project_name}-${var.env}-ec2-cloudwatch-"
  description = "Custom CloudWatch permissions for EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-ec2-cloudwatch-policy"
  })
}

# Attach custom CloudWatch policy to EC2 role
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_custom" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_cloudwatch_custom.arn
}

# ========================================
# Security Groups
# ========================================

# Security group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.env}-alb-"
  vpc_id      = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.existing[0].id

  # HTTP access from allowed CIDRs
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security group for EC2 instances
resource "aws_security_group" "ec2" {
  name_prefix = "${var.project_name}-${var.env}-ec2-"
  vpc_id      = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.existing[0].id

  # HTTP access from ALB security group
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # HTTPS access for VPC endpoints
  ingress {
    description = "HTTPS for VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-ec2-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# KMS Key for WAF Logs
# ========================================

# KMS key for WAF log encryption
resource "aws_kms_key" "waf_logs" {
  description             = "KMS key for WAF log encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-waf-logs-key"
  })
}

# KMS key alias
resource "aws_kms_alias" "waf_logs" {
  name          = "alias/${var.project_name}-${var.env}-waf-logs"
  target_key_id = aws_kms_key.waf_logs.key_id
}



# ========================================
# WAF Configuration
# ========================================

# WAF Web ACL for Application Load Balancer
resource "aws_wafv2_web_acl" "main" {
  count = var.create_waf ? 1 : 0

  name  = "${var.project_name}-${var.env}-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }

    action {
      block {}
    }
  }

  # AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.env}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-web-acl"
  })
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf_log_group" {
  name              = "/aws/wafv2/${var.project_name}-${var.env}"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = aws_kms_key.waf_logs.arn

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-waf-logs"
  })
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.create_waf ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_log_group.arn]
}