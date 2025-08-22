# Staging Environment Configuration
env = "staging"
project_name = "secure-cicd-pipeline"

# Network Configuration
vpc_cidr = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Compute Configuration (production-like)
instance_type = "t3.small"
instance_count = 2
enable_detailed_monitoring = true

# Security Configuration
allowed_http_cidrs = ["0.0.0.0/0"]  # Restrict as needed

# Monitoring Configuration
enable_enhanced_monitoring = true
log_retention_days = 14

# Cost Control
enable_cost_monitoring = true
budget_limit = 75

# Backup Configuration
backup_retention_days = 14

# Tags
additional_tags = {
  Environment = "staging"
  Purpose = "pre-production-validation"
  CostCenter = "development"
}