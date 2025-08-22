# ========================================
# Preview Environment Configuration
# ========================================

# Project Configuration
project_name = "webserverdeployment"
env          = "preview"

# AWS Configuration
aws_region = "us-east-1"

# Network Configuration
cidr_block         = "10.10.0.0/16"  # Dedicated CIDR for preview environments
az_count           = 2
allowed_http_cidrs = [
  "0.0.0.0/0"  # Open access for preview testing
]

# Compute Configuration - Minimal resources for cost optimization
instance_type  = "t3.micro"
instance_count = 1  # Single instance for preview

# Security Configuration
kms_key_id                 = null   # Use default AWS managed key
enable_detailed_monitoring = false  # Basic monitoring for preview

# Environment-specific Configuration
enable_preview        = true   # Enable preview-specific features
backup_retention_days = 1      # Minimal retention for preview

# Monitoring Configuration
sns_email_endpoints = [
  "devops-preview@example.com"
]
cloudwatch_log_retention_days = 3  # Minimal retention for preview

# WAF Configuration - Relaxed for development testing
waf_rate_limit = 10000  # Higher limit for development testing

# Patch Management Configuration
patch_schedule = "cron(0 4 ? * SUN *)"  # Sundays at 4 AM UTC

# Tagging Configuration
cost_center = "devops"
additional_tags = {
  "Owner"           = "DevOps Team"
  "Application"     = "Web Server Deployment"
  "Environment"     = "preview"
  "Temporary"       = "true"
  "AutoCleanup"     = "true"
  "Backup"          = "none"
  "Monitoring"      = "basic"
  "Purpose"         = "feature-branch-testing"
  "CostOptimized"   = "true"
}

# Cost Monitoring Configuration - Preview Environment
enable_cost_monitoring            = true
monthly_budget_limit             = 15   # Very low budget for preview
budget_alert_emails              = [
  "devops-preview@example.com"
]
enable_sns_cost_alerts           = false
enable_cloudwatch_billing_alarms = true
cloudwatch_billing_threshold     = 10   # Alert at $10 for preview
enable_cost_anomaly_detection    = false # Disabled for preview
cost_anomaly_threshold           = 5    # Very low threshold for preview