# Cost Monitoring and Budget Alerts
# This file implements AWS Budgets for cost monitoring and alerting

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current AWS region
data "aws_region" "current" {}

# Budget for monthly cost monitoring
resource "aws_budgets_budget" "monthly_cost_budget" {
  count = var.enable_cost_monitoring ? 1 : 0

  name         = "${var.project_name}-${var.env}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", plantimestamp())

  cost_filters = {
    Tag = [
      "Project:${var.project_name}",
      "Environment:${var.env}"
    ]
  }

  # Alert when 80% of budget is reached
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Alert when 100% of budget is reached
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  # Forecast alert when projected to exceed 120% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 120
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.env}-monthly-budget"
      Description = "Monthly cost budget for ${var.project_name} ${var.env} environment"
    }
  )
}

# SNS Topic for cost alerts (if not using email directly)
resource "aws_sns_topic" "cost_alerts" {
  count = var.enable_cost_monitoring && var.enable_sns_cost_alerts ? 1 : 0

  name = "${var.project_name}-${var.env}-cost-alerts"

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.env}-cost-alerts"
      Description = "SNS topic for cost monitoring alerts"
    }
  )
}

# SNS Topic Subscription for cost alerts
resource "aws_sns_topic_subscription" "cost_alert_email" {
  count = var.enable_cost_monitoring && var.enable_sns_cost_alerts ? length(var.budget_alert_emails) : 0

  topic_arn = aws_sns_topic.cost_alerts[0].arn
  protocol  = "email"
  endpoint  = var.budget_alert_emails[count.index]
}

# CloudWatch Alarm for estimated charges (alternative monitoring)
resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  count = var.enable_cost_monitoring && var.enable_cloudwatch_billing_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.env}-estimated-charges"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400" # 24 hours
  statistic           = "Maximum"
  threshold           = var.cloudwatch_billing_threshold
  alarm_description   = "This metric monitors estimated charges for ${var.project_name} ${var.env}"
  alarm_actions       = var.enable_sns_cost_alerts ? [aws_sns_topic.cost_alerts[0].arn] : []

  dimensions = {
    Currency = "USD"
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.env}-estimated-charges"
      Description = "CloudWatch alarm for estimated billing charges"
    }
  )
}

# Cost anomaly detection (for advanced cost monitoring)
resource "aws_ce_anomaly_detector" "cost_anomaly" {
  count = var.enable_cost_monitoring && var.enable_cost_anomaly_detection ? 1 : 0

  name         = "${var.project_name}-${var.env}-cost-anomaly"
  monitor_type = "DIMENSIONAL"

  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = ["Amazon Elastic Compute Cloud - Compute", "Amazon Elastic Load Balancing", "Amazon Virtual Private Cloud"]
  })

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.env}-cost-anomaly"
      Description = "Cost anomaly detection for ${var.project_name} ${var.env}"
    }
  )
}

# Cost anomaly subscription
resource "aws_ce_anomaly_subscription" "cost_anomaly_subscription" {
  count = var.enable_cost_monitoring && var.enable_cost_anomaly_detection ? 1 : 0

  name      = "${var.project_name}-${var.env}-cost-anomaly-subscription"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.cost_anomaly[0].arn
  ]

  subscriber {
    type    = "EMAIL"
    address = length(var.budget_alert_emails) > 0 ? var.budget_alert_emails[0] : "admin@example.com"
  }

  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = [tostring(var.cost_anomaly_threshold)]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.env}-cost-anomaly-subscription"
      Description = "Cost anomaly subscription for ${var.project_name} ${var.env}"
    }
  )
}

# Output cost monitoring information
output "cost_monitoring_enabled" {
  description = "Whether cost monitoring is enabled"
  value       = var.enable_cost_monitoring
}

output "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  value       = var.enable_cost_monitoring ? var.monthly_budget_limit : null
}

output "budget_name" {
  description = "Name of the AWS Budget"
  value       = var.enable_cost_monitoring ? aws_budgets_budget.monthly_cost_budget[0].name : null
}

output "cost_alerts_topic_arn" {
  description = "ARN of the SNS topic for cost alerts"
  value       = var.enable_cost_monitoring && var.enable_sns_cost_alerts ? aws_sns_topic.cost_alerts[0].arn : null
}