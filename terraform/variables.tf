# Project Configuration
variable "project_name" {
  description = "Name of the project used for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "env" {
  description = "Environment identifier (test/staging/prod/preview)"
  type        = string
  validation {
    condition     = can(regex("^(test|staging|prod|preview).*$", var.env))
    error_message = "Environment must start with: test, staging, prod, or preview."
  }
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# Network Configuration
variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "CIDR block must be a valid IPv4 CIDR."
  }
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "AZ count must be between 2 and 4."
  }
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to access ALB on HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Default for development - should be restricted in production
  validation {
    condition = alltrue([
      for cidr in var.allowed_http_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid IPv4 CIDRs."
  }
}

# Compute Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium", "t3.large",
      "t3a.micro", "t3a.small", "t3a.medium", "t3a.large",
      "m5.large", "m5.xlarge", "m5a.large", "m5a.xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a valid EC2 instance type from the allowed list."
  }
}

variable "instance_count" {
  description = "Number of EC2 instances to launch"
  type        = number
  default     = 2
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

# Security Configuration
variable "kms_key_id" {
  description = "KMS key ID for EBS encryption (optional)"
  type        = string
  default     = null
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2 instances"
  type        = bool
  default     = false
}

# Environment-specific Configuration
variable "enable_preview" {
  description = "Enable preview environment features"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}

# Monitoring Configuration
variable "sns_email_endpoints" {
  description = "List of email addresses for SNS notifications"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for email in var.sns_email_endpoints : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All email addresses must be valid."
  }
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.cloudwatch_log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# WAF Configuration
variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5 minutes)"
  type        = number
  default     = 2000
  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 20000000
    error_message = "WAF rate limit must be between 100 and 20,000,000."
  }
}

# Patch Management Configuration
variable "patch_schedule" {
  description = "Cron expression for patch schedule (UTC)"
  type        = string
  default     = "cron(0 2 ? * SUN *)" # Sundays at 2 AM UTC
  validation {
    condition     = can(regex("^cron\\(", var.patch_schedule))
    error_message = "Patch schedule must be a valid cron expression."
  }
}

# Tagging Configuration
variable "cost_center" {
  description = "Cost center for resource tagging"
  type        = string
  default     = "devops"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevOps Team"
}

variable "application" {
  description = "Application name for resource tagging"
  type        = string
  default     = "Web Server Deployment"
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Cost Monitoring Configuration
variable "enable_cost_monitoring" {
  description = "Enable AWS Budgets and cost monitoring features"
  type        = bool
  default     = true
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD for cost monitoring"
  type        = number
  default     = 100
  
  validation {
    condition     = var.monthly_budget_limit > 0
    error_message = "Monthly budget limit must be greater than 0."
  }
}

variable "budget_alert_emails" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
  default     = ["shublaisengwa@gmail.com"]
  
  validation {
    condition = alltrue([
      for email in var.budget_alert_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All budget alert emails must be valid email addresses."
  }
}

variable "enable_sns_cost_alerts" {
  description = "Enable SNS topic for cost alerts (alternative to direct email)"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_billing_alarms" {
  description = "Enable CloudWatch billing alarms for estimated charges"
  type        = bool
  default     = true
}

variable "cloudwatch_billing_threshold" {
  description = "CloudWatch billing alarm threshold in USD"
  type        = number
  default     = 80
  
  validation {
    condition     = var.cloudwatch_billing_threshold > 0
    error_message = "CloudWatch billing threshold must be greater than 0."
  }
}

variable "enable_cost_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection"
  type        = bool
  default     = false
}

variable "cost_anomaly_threshold" {
  description = "Cost anomaly detection threshold in USD"
  type        = number
  default     = 20
  
  validation {
    condition     = var.cost_anomaly_threshold > 0
    error_message = "Cost anomaly threshold must be greater than 0."
  }
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 14
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring"
  type        = bool
  default     = false
}

variable "budget_limit" {
  description = "Budget limit in USD"
  type        = number
  default     = 100
}

# Conditional Resource Creation
variable "create_alb" {
  description = "Create Application Load Balancer"
  type        = bool
  default     = true
}

variable "create_waf" {
  description = "Create WAF Web ACL"
  type        = bool
  default     = true
}

variable "create_patch_baseline" {
  description = "Create SSM Patch Baseline and Patch Group"
  type        = bool
  default     = true
}

variable "create_vpc" {
  description = "Create VPC and networking resources"
  type        = bool
  default     = true
}

variable "create_instances" {
  description = "Create EC2 instances"
  type        = bool
  default     = true
}