# ========================================
# Production Environment Configuration
# ========================================

# Project Configuration
project_name = "secure-cicd-pipeline"
env          = "prod"

# AWS Configuration
aws_region = "us-east-1"

# Network Configuration
cidr_block         = "10.2.0.0/16"  # Dedicated CIDR for production
az_count           = 2
allowed_http_cidrs = [
  "0.0.0.0/0"  # Public access for production web application
]

# Compute Configuration - Production sizing
instance_type  = "t3.small"  # Adequate for production workload
instance_count = 2           # Multi-instance for high availability

# Security Configuration
kms_key_id                 = null  # Use default AWS managed key (consider custom KMS key)
enable_detailed_monitoring = true  # Full monitoring for production

# Environment-specific Configuration
enable_preview        = false
backup_retention_days = 30  # Extended retention for production

# Monitoring Configuration
sns_email_endpoints = [
  "devops-prod@example.com",
  "oncall@example.com",
  "management@example.com"
]
cloudwatch_log_retention_days = 90  # Extended retention for compliance

# WAF Configuration - Strict security for production
waf_rate_limit = 2000  # Standard rate limiting

# Patch Management Configuration
patch_schedule = "cron(0 2 ? * SUN *)"  # Sundays at 2 AM UTC

# Tagging Configuration
cost_center = "devops"
additional_tags = {
  "Owner"           = "DevOps Team"
  "Application"     = "Secure CI/CD Pipeline"
  "Environment"     = "prod"
  "CriticalSystem"  = "true"
  "Backup"          = "required"
  "Monitoring"      = "enhanced"
  "Purpose"         = "production-workload"
  "ApprovalGate"    = "senior-team-required"
  "ChangeWindow"    = "business-hours-only"
  "Compliance"      = "required"
}# Cost M
onitoring Configuration - Production Environment
enable_cost_monitoring            = true
monthly_budget_limit             = 150  # Higher budget for production
budget_alert_emails              = [
  "devops-prod@example.com",
  "finance@example.com",
  "management@example.com"
]
enable_sns_cost_alerts           = true  # Enable SNS for production alerts
enable_cloudwatch_billing_alarms = true
cloudwatch_billing_threshold     = 120  # Alert at $120 for production
enable_cost_anomaly_detection    = true  # Enable for production monitoring
cost_anomaly_threshold           = 25   # Higher threshold for production