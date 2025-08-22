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

# ========================================
# Application Load Balancer
# ========================================

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = var.env == "prod" ? true : false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-alb"
  })
}

# Target Group for EC2 instances
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-${var.env}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

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

# ALB Listener for HTTP traffic
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-alb-listener"
  })
}

# Associate WAF Web ACL with ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
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
  count = var.instance_count

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[count.index % var.az_count].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = local.user_data
  monitoring             = var.enable_detailed_monitoring

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
    Name          = "${var.project_name}-${var.env}-instance-${count.index + 1}"
    "Patch Group" = "${var.project_name}-${var.env}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Attach EC2 instances to target group
resource "aws_lb_target_group_attachment" "main" {
  count = var.instance_count

  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.main[count.index].id
  port             = 80
}