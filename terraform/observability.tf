# ========================================
# SNS Topic and Subscriptions
# ========================================

# SNS topic for infrastructure alerts
resource "aws_sns_topic" "infrastructure_alerts" {
  name = "${var.project_name}-${var.env}-infrastructure-alerts"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-infrastructure-alerts"
  })
}

# SNS topic policy to allow CloudWatch to publish
resource "aws_sns_topic_policy" "infrastructure_alerts" {
  arn = aws_sns_topic.infrastructure_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.infrastructure_alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Email subscriptions for SNS topic
resource "aws_sns_topic_subscription" "email_alerts" {
  count = length(var.sns_email_endpoints)

  topic_arn = aws_sns_topic.infrastructure_alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoints[count.index]
}

# ========================================
# CloudWatch Alarms for EC2 Instances
# ========================================

# CloudWatch alarm for EC2 StatusCheckFailed
resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  count = var.instance_count

  alarm_name          = "${var.project_name}-${var.env}-ec2-status-check-failed-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors ec2 status check failed for instance ${aws_instance.main[count.index].id}"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]
  ok_actions          = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    InstanceId = aws_instance.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-ec2-status-check-alarm-${count.index + 1}"
  })
}

# CloudWatch alarm for EC2 CPU utilization
resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  count = var.instance_count

  alarm_name          = "${var.project_name}-${var.env}-ec2-high-cpu-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization for instance ${aws_instance.main[count.index].id}"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]
  ok_actions          = [aws_sns_topic.infrastructure_alerts.arn]

  dimensions = {
    InstanceId = aws_instance.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-ec2-high-cpu-alarm-${count.index + 1}"
  })
}

# ========================================
# CloudWatch Alarms for Application Load Balancer
# ========================================

# CloudWatch alarm for ALB 5xx errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.env}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors ALB 5xx error count"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]
  ok_actions          = [aws_sns_topic.infrastructure_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.create_alb ? aws_lb.main[0].arn_suffix : data.aws_lb.existing[0].arn_suffix
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-alb-5xx-errors-alarm"
  })
}

# CloudWatch alarm for ALB target health
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.project_name}-${var.env}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors ALB unhealthy target count"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]
  ok_actions          = [aws_sns_topic.infrastructure_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = var.create_alb ? aws_lb_target_group.main[0].arn_suffix : data.aws_lb_target_group.existing[0].arn_suffix
    LoadBalancer = var.create_alb ? aws_lb.main[0].arn_suffix : data.aws_lb.existing[0].arn_suffix
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-alb-unhealthy-targets-alarm"
  })
}

# ========================================
# CloudWatch Dashboard (Optional)
# ========================================

# CloudWatch dashboard for infrastructure monitoring
resource "aws_cloudwatch_dashboard" "infrastructure" {
  dashboard_name = "${var.project_name}-${var.env}-infrastructure"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for i in range(var.instance_count) : [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              aws_instance.main[i].id
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "EC2 CPU Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              var.create_alb ? aws_lb.main[0].arn_suffix : data.aws_lb.existing[0].arn_suffix
            ],
            [
              ".",
              "HTTPCode_ELB_5XX_Count",
              ".",
              "."
            ],
            [
              ".",
              "HTTPCode_Target_2XX_Count",
              ".",
              "."
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ALB Request Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "HealthyHostCount",
              "TargetGroup",
              var.create_alb ? aws_lb_target_group.main[0].arn_suffix : data.aws_lb_target_group.existing[0].arn_suffix,
              "LoadBalancer",
              var.create_alb ? aws_lb.main[0].arn_suffix : data.aws_lb.existing[0].arn_suffix
            ],
            [
              ".",
              "UnHealthyHostCount",
              ".",
              ".",
              ".",
              "."
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Target Group Health"
          period  = 300
        }
      }
    ]
  })


}

