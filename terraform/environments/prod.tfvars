# Production Environment Configuration
env = "prod"
project_name = "webserverdeployment"

# Network Configuration
vpc_cidr = "10.2.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Compute Configuration (full production)
instance_type = "t3.small"
instance_count = 3
enable_detailed_monitoring = true

# Security Configuration - RESTRICT ACCESS
# allowed_http_cidrs = []  # Define specific IP ranges for production

# Monitoring Configuration
enable_enhanced_monitoring = true
log_retention_days = 30

# Cost Control
enable_cost_monitoring = true
budget_limit = 150

# Backup Configuration
backup_retention_days = 30

# Tags
additional_tags = {
  Environment = "production"
  Purpose = "live-application"
  CostCenter = "operations"
  Compliance = "required"
}