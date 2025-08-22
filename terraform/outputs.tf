# ========================================
# Network Outputs
# ========================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

# ========================================
# Load Balancer Outputs
# ========================================

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

# ========================================
# EC2 Outputs
# ========================================

output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = aws_instance.main[*].id
}

output "instance_private_ips" {
  description = "Private IP addresses of the EC2 instances"
  value       = aws_instance.main[*].private_ip
}

# ========================================
# Security Outputs
# ========================================

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

# ========================================
# Monitoring Outputs
# ========================================

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.infrastructure_alerts.arn
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.infrastructure.dashboard_name}"
}

# ========================================
# Patch Management Outputs
# ========================================

output "patch_baseline_id" {
  description = "ID of the SSM patch baseline"
  value       = aws_ssm_patch_baseline.amazon_linux.id
}

output "patch_group_name" {
  description = "Name of the patch group"
  value       = aws_ssm_patch_group.main.patch_group
}

output "patch_logs_bucket" {
  description = "Name of the S3 bucket for patch logs"
  value       = aws_s3_bucket.patch_logs.bucket
}

# ========================================
# Environment Information Outputs
# ========================================

output "environment" {
  description = "Environment name"
  value       = var.env
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# ========================================
# Application URL and Access Information
# ========================================

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "application_health_check_url" {
  description = "URL for application health checks"
  value       = "http://${aws_lb.main.dns_name}/"
}

# ========================================
# Resource Summary for CI/CD
# ========================================

output "deployment_summary" {
  description = "Summary of deployed resources for CI/CD reporting"
  value = {
    project_name     = var.project_name
    environment      = var.env
    region          = var.aws_region
    vpc_id          = aws_vpc.main.id
    alb_dns_name    = aws_lb.main.dns_name
    instance_count  = var.instance_count
    instance_ids    = aws_instance.main[*].id
    deployment_time = timestamp()
  }
}

# ========================================
# Monitoring and Alerting Outputs
# ========================================

output "cloudwatch_alarms" {
  description = "List of CloudWatch alarm names for monitoring"
  value = concat(
    aws_cloudwatch_metric_alarm.ec2_status_check_failed[*].alarm_name,
    aws_cloudwatch_metric_alarm.ec2_high_cpu[*].alarm_name,
    [
      aws_cloudwatch_metric_alarm.alb_5xx_errors.alarm_name,
      aws_cloudwatch_metric_alarm.alb_unhealthy_targets.alarm_name,
      aws_cloudwatch_metric_alarm.patch_compliance_failure.alarm_name
    ]
  )
}

