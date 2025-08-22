# ========================================
# Compute Infrastructure
# ========================================

# Data source for Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# ========================================
# S3 Bucket for ALB Access Logs
# ========================================

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_access_logs" {
  count = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == "" ? 1 : 0

  bucket        = "${var.project_name}-${var.env}-alb-access-logs-${random_id.bucket_suffix[0].hex}"
  force_destroy = var.env != "prod"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-alb-access-logs"
  })
}

# Random ID for bucket suffix to ensure uniqueness
resource "random_id" "bucket_suffix" {
  count = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == "" ? 1 : 0

  byte_length = 4
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "alb_access_logs" {
  count = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == "" ? 1 : 0

  bucket = aws_s3_bucket.alb_access_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_access_logs" {
  count = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == "" ? 1 : 0

  bucket = aws_s3_bucket.alb_access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "alb_access_logs" {
  count = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == "" ? 1 : 0

  bucket = aws_s3_bucket.alb_access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for ALB access logs
resource "aws_s3_bucket_policy" "alb_access_logs" {
  count = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == "" ? 1 : 0

  bucket = aws_s3_bucket.alb_access_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_elb_service_account.main.id}:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_access_logs[0].arn}/${var.project_name}-${var.env}-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_access_logs[0].arn}/${var.project_name}-${var.env}-alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_access_logs[0].arn
      }
    ]
  })
}

# Data source for ELB service account
data "aws_elb_service_account" "main" {}

# ========================================
# Application Load Balancer
# ========================================

# Application Load Balancer
resource "aws_lb" "main" {
  count = var.create_alb ? 1 : 0

  name               = "${var.project_name}-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.create_vpc ? aws_subnet.public[*].id : data.aws_subnets.existing[0].ids

  enable_deletion_protection = var.env == "prod" ? true : false
  drop_invalid_header_fields = true

  # Access logging configuration
  access_logs {
    bucket  = var.alb_access_logs_bucket != "" ? var.alb_access_logs_bucket : (var.enable_alb_access_logs ? aws_s3_bucket.alb_access_logs[0].bucket : "")
    prefix  = "${var.project_name}-${var.env}-alb"
    enabled = var.enable_alb_access_logs
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-alb"
  })
}

# Target Group for EC2 instances
resource "aws_lb_target_group" "main" {
  count = var.create_alb ? 1 : 0

  name     = "${var.project_name}-${var.env}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.create_vpc ? aws_vpc.main[0].id : data.aws_vpc.existing[0].id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-target-group"
  })
}

# ALB Listener for HTTP traffic (redirects to HTTPS)
resource "aws_lb_listener" "http" {
  count = var.create_alb ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-alb-http-listener"
  })
}

# ALB Listener for HTTPS traffic
resource "aws_lb_listener" "https" {
  count = var.create_alb && var.ssl_certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-alb-https-listener"
  })
}

# Associate WAF Web ACL with ALB
resource "aws_wafv2_web_acl_association" "main" {
  count = var.create_alb && var.create_waf ? 1 : 0

  resource_arn = aws_lb.main[0].arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# ========================================
# EC2 Instances
# ========================================

# User data script for EC2 instances
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
    environment  = var.env
  }))
}

# EC2 instances in private subnets
resource "aws_instance" "main" {
  count = var.create_instances ? var.instance_count : 0

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.create_vpc ? aws_subnet.private[count.index % var.az_count].id : data.aws_subnets.existing_private[0].ids[count.index % length(data.aws_subnets.existing_private[0].ids)]
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = local.user_data
  monitoring             = var.enable_detailed_monitoring
  ebs_optimized          = true

  # Security hardening - require IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Encrypted EBS root volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = true

    tags = merge(local.common_tags, {
      Name = "${var.project_name}-${var.env}-root-volume-${count.index + 1}"
    })
  }

  # Patch group tagging for SSM
  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-${var.env}-instance-${count.index + 1}"
    PatchGroup = "${var.project_name}-${var.env}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Attach EC2 instances to target group
resource "aws_lb_target_group_attachment" "main" {
  count = var.create_alb && var.create_instances ? var.instance_count : 0

  target_group_arn = aws_lb_target_group.main[0].arn
  target_id        = aws_instance.main[count.index].id
  port             = 80
}