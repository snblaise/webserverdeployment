# Cost Monitoring and Analysis

This document describes the cost monitoring and analysis features implemented in the secure CI/CD pipeline.

## Overview

The infrastructure includes comprehensive cost monitoring and alerting capabilities to help manage and control AWS spending. This includes:

- **Infracost Integration**: Real-time cost estimation in CI/CD pipeline
- **AWS Budgets**: Monthly budget limits with email alerts
- **CloudWatch Billing Alarms**: Threshold-based cost alerts
- **Cost Anomaly Detection**: Automated detection of unusual spending patterns
- **Cost Threshold Warnings**: PR comments with cost analysis and warnings

## Features

### 1. Infracost Integration

Infracost provides cost estimates for infrastructure changes directly in pull requests.

**Configuration:**
- Runs automatically on all pull requests
- Generates cost breakdown and diff analysis
- Comments cost estimates in PR with threshold warnings
- Uploads cost analysis artifacts for detailed review

**Setup Requirements:**
1. Sign up for a free Infracost API key at https://www.infracost.io/
2. Add the API key as `INFRACOST_API_KEY` in repository secrets
3. Configure cost thresholds using repository variables:
   - `COST_THRESHOLD_WARNING`: Warning threshold (default: $50/month)
   - `COST_THRESHOLD_MONTHLY`: Critical threshold (default: $100/month)

### 2. AWS Budgets

AWS Budgets provide proactive cost monitoring with email alerts.

**Features:**
- Monthly budget limits per environment
- Email alerts at 80%, 100%, and 120% (forecasted) of budget
- Tag-based cost filtering by project and environment
- Configurable budget limits per environment

**Configuration Variables:**
```hcl
# Enable/disable cost monitoring
enable_cost_monitoring = true

# Monthly budget limit in USD
monthly_budget_limit = 100

# Email addresses for budget alerts
budget_alert_emails = [
  "devops@example.com",
  "finance@example.com"
]
```

### 3. CloudWatch Billing Alarms

CloudWatch billing alarms provide additional cost monitoring through AWS CloudWatch.

**Features:**
- Daily monitoring of estimated charges
- Configurable threshold amounts
- Integration with SNS for notifications
- Per-environment threshold configuration

**Configuration Variables:**
```hcl
# Enable CloudWatch billing alarms
enable_cloudwatch_billing_alarms = true

# Threshold amount in USD
cloudwatch_billing_threshold = 80
```

### 4. Cost Anomaly Detection

AWS Cost Anomaly Detection automatically identifies unusual spending patterns.

**Features:**
- Machine learning-based anomaly detection
- Daily email notifications for anomalies
- Configurable minimum anomaly threshold
- Service-specific monitoring (EC2, ELB, VPC)

**Configuration Variables:**
```hcl
# Enable cost anomaly detection
enable_cost_anomaly_detection = true

# Minimum anomaly amount to trigger alert (USD)
cost_anomaly_threshold = 20
```

## Environment-Specific Configuration

### Test Environment
- **Budget**: $25/month
- **Threshold**: $20
- **Anomaly Detection**: Disabled
- **Purpose**: Cost-optimized testing

### Staging Environment
- **Budget**: $75/month
- **Threshold**: $60
- **Anomaly Detection**: Enabled
- **Purpose**: Production-like validation

### Production Environment
- **Budget**: $150/month
- **Threshold**: $120
- **Anomaly Detection**: Enabled
- **Purpose**: Full monitoring and alerting

### Preview Environment
- **Budget**: $15/month
- **Threshold**: $10
- **Anomaly Detection**: Disabled
- **Purpose**: Minimal cost for feature testing

## Cost Optimization Strategies

### 1. Instance Sizing
- **Test/Preview**: t3.micro instances
- **Staging**: t3.small instances (production-like)
- **Production**: t3.small or larger based on requirements

### 2. Resource Lifecycle
- **Preview environments**: Automatic cleanup on PR closure
- **Test environments**: Short backup retention (7 days)
- **Production**: Extended retention for compliance (30 days)

### 3. Monitoring Levels
- **Basic**: Test and preview environments
- **Enhanced**: Staging and production environments
- **Detailed**: Production only with extended log retention

## Alerts and Notifications

### Budget Alerts
- **80% of budget**: Warning notification
- **100% of budget**: Critical notification
- **120% of budget**: Forecasted overage alert

### Cost Threshold Warnings in PRs
- **Warning threshold**: Yellow warning in PR comment
- **Critical threshold**: Red alert in PR comment with recommendations

### Anomaly Detection
- **Daily reports**: Email notifications for detected anomalies
- **Threshold-based**: Only alerts for anomalies above configured amount

## Troubleshooting

### Infracost Not Working
1. **Check API Key**: Verify `INFRACOST_API_KEY` secret is configured
2. **Check Permissions**: Ensure GitHub Actions has access to secrets
3. **Check Logs**: Review workflow logs for Infracost errors
4. **Network Issues**: Verify connectivity to Infracost API

### Budget Alerts Not Received
1. **Check Email Addresses**: Verify email addresses in `budget_alert_emails`
2. **Check AWS Budgets**: Verify budget is created in AWS console
3. **Check Permissions**: Ensure Terraform has budgets permissions
4. **Check Filters**: Verify tag-based filtering is working correctly

### Cost Anomaly Detection Issues
1. **Check Configuration**: Verify anomaly detection is enabled
2. **Check Threshold**: Ensure threshold is appropriate for environment
3. **Check Service Coverage**: Verify monitored services are correct
4. **Check Permissions**: Ensure Cost Explorer permissions are granted

## Best Practices

### 1. Regular Review
- Review cost reports monthly
- Analyze cost trends and anomalies
- Adjust budgets based on actual usage

### 2. Environment Hygiene
- Clean up unused preview environments
- Monitor test environment usage
- Implement auto-cleanup policies

### 3. Resource Optimization
- Right-size instances based on actual usage
- Use appropriate storage types
- Implement lifecycle policies for logs and backups

### 4. Alert Management
- Configure appropriate email distribution lists
- Set realistic thresholds based on expected usage
- Review and update thresholds regularly

## Cost Monitoring Outputs

The Terraform configuration provides several outputs for cost monitoring:

```hcl
# Check if cost monitoring is enabled
output "cost_monitoring_enabled"

# Get budget information
output "monthly_budget_limit"
output "budget_name"

# Get alert configuration
output "cost_alerts_topic_arn"
output "cloudwatch_billing_alarm_name"

# Get anomaly detection info
output "cost_anomaly_detector_arn"

# Get complete cost monitoring summary
output "cost_monitoring_summary"
```

## Integration with CI/CD

The cost monitoring integrates seamlessly with the CI/CD pipeline:

1. **Pull Request Validation**: Cost estimates and threshold warnings
2. **Deployment Tracking**: Cost impact of infrastructure changes
3. **Environment Management**: Per-environment budget tracking
4. **Automated Cleanup**: Cost-aware resource lifecycle management

## Security Considerations

- **API Keys**: Infracost API key stored securely in GitHub secrets
- **Email Security**: Budget alert emails should use secure distribution lists
- **Access Control**: Cost monitoring resources use least-privilege IAM policies
- **Data Privacy**: Cost data is handled according to AWS security best practices

## Support and Resources

- **Infracost Documentation**: https://www.infracost.io/docs/
- **AWS Budgets Guide**: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html
- **Cost Anomaly Detection**: https://docs.aws.amazon.com/cost-management/latest/userguide/getting-started-ad.html
- **CloudWatch Billing**: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/monitor_estimated_charges_with_cloudwatch.html