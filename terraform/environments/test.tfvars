# ========================================
# Test Environment Configuration
# ========================================

# Project Configuration
project_name = "secure-cicd-pipeline"
env          = "test"

# AWS Configuration
aws_region = "us-east-1"

# Network Configuration
cidr_block         = "10.0.0.0/16"
az_count           = 2
allowed_http_cidrs = ["0.0.0.0/0"]  # Open for testing

# Compute Configuration - Minimal resources for cost optimization
instance_type  = "t3.micro"
instance_count = 1  # Single instance for testing

# Security Configuration
kms_key_id                 = null   # Use default AWS managed key
enable_detailed_monitoring = false  # Basic monitoring for test

# Environment-specific Configuration
enable_preview        = false
backup_retention_days = 7  # Short retention for test environment

# Monitoring Configuration
sns_email_endpoints = [
  "devops-test@example.com"
]
cloudwatch_log_retention_days = 7  # Short retention for test

# WAF Configuration - Relaxed for testing
waf_rate_limit = 5000  # Higher limit for load testing

# Patch Management Configuration
patch_schedule = "cron(0 3 ? * SUN *)"  # Sundays at 3 AM UTC

# Tagging Configuration
cost_center = "devops"
additional_tags = {
  "Owner"           = "DevOps Team"
  "Application"     = "Secure CI/CD Pipeline"
  "Environment"     = "test"
  "CostOptimized"   = "true"
  "AutoCleanup"     = "true"
  "Backup"          = "optional"
  "Monitoring"      = "basic"
  "Purpose"         = "automated-testing"
}# Cost Mo
nitoring Configuration - Test Environment
enable_cost_monitoring            = true
monthly_budget_limit             = 25   # Lower budget for test environment
budget_alert_emails              = [
  "devops-test@example.com"
]
enable_sns_cost_alerts           = false
enable_cloudwatch_billing_alarms = true
cloudwatch_billing_threshold     = 20   # Alert at $20 for test
enable_cost_anomaly_detection    = false # Disabled for test environment
cost_anomaly_threshold           = 10   # Lower threshold for test