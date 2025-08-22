# ========================================
# Staging Environment Configuration
# ========================================

# Project Configuration
project_name = "secure-cicd-pipeline"
env          = "staging"

# AWS Configuration
aws_region = "us-east-1"

# Network Configuration
cidr_block         = "10.1.0.0/16"  # Different CIDR for staging
az_count           = 2
allowed_http_cidrs = [
  "10.0.0.0/8",      # Internal networks
  "172.16.0.0/12",   # Private networks
  "192.168.0.0/16"   # Local networks
]

# Compute Configuration - Production-like sizing
instance_type  = "t3.small"  # Match production sizing
instance_count = 2           # Multi-instance for HA testing

# Security Configuration
kms_key_id                 = null  # Use default AWS managed key
enable_detailed_monitoring = true  # Enhanced monitoring for staging

# Environment-specific Configuration
enable_preview        = false
backup_retention_days = 14  # Medium retention for staging

# Monitoring Configuration
sns_email_endpoints = [
  "devops-staging@example.com",
  "qa-team@example.com"
]
cloudwatch_log_retention_days = 30  # Extended retention for staging

# WAF Configuration - Production-like security
waf_rate_limit = 2000  # Production-like rate limiting

# Patch Management Configuration
patch_schedule = "cron(0 2 ? * SUN *)"  # Sundays at 2 AM UTC

# Tagging Configuration
cost_center = "devops"
additional_tags = {
  "Owner"           = "DevOps Team"
  "Application"     = "Secure CI/CD Pipeline"
  "Environment"     = "staging"
  "ProductionLike"  = "true"
  "Backup"          = "required"
  "Monitoring"      = "enhanced"
  "Purpose"         = "pre-production-validation"
  "ApprovalGate"    = "required"
}# Cost 
Monitoring Configuration - Staging Environment
enable_cost_monitoring            = true
monthly_budget_limit             = 75   # Medium budget for staging
budget_alert_emails              = [
  "devops-staging@example.com",
  "finance@example.com"
]
enable_sns_cost_alerts           = false
enable_cloudwatch_billing_alarms = true
cloudwatch_billing_threshold     = 60   # Alert at $60 for staging
enable_cost_anomaly_detection    = true  # Enable for staging validation
cost_anomaly_threshold           = 15   # Medium threshold for staging