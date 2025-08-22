# Test Environment Configuration
env = "test"
project_name = "webserverdeployment"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Compute Configuration (cost-optimized for testing)
instance_type = "t3.micro"
instance_count = 1
enable_detailed_monitoring = false

# Security Configuration
allowed_http_cidrs = ["0.0.0.0/0"]  # Open for testing - restrict in production

# Monitoring Configuration
enable_enhanced_monitoring = false
log_retention_days = 7

# Cost Control
enable_cost_monitoring = true
budget_limit = 25

# Backup Configuration
backup_retention_days = 7

# Tags
additional_tags = {
  Environment = "test"
  Purpose = "automated-testing"
  CostCenter = "development"
}