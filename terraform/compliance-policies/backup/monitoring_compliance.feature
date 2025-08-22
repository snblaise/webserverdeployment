Feature: Monitoring and logging must be properly configured
  In order to ensure proper observability
  As a security engineer
  I want to ensure monitoring and logging are properly configured

  Scenario: CloudWatch alarms should have proper configuration
    Given I have aws_cloudwatch_metric_alarm defined
    Then it must contain alarm_name
    And it must contain comparison_operator
    And it must contain evaluation_periods
    And it must contain metric_name
    And it must contain namespace
    And it must contain period
    And it must contain statistic
    And it must contain threshold

  Scenario: CloudWatch alarms should have alarm actions configured
    Given I have aws_cloudwatch_metric_alarm defined
    When it contains alarm_actions
    Then its value must not be null

  Scenario: SNS topics should have proper naming
    Given I have aws_sns_topic defined
    Then it must contain name_prefix
    And its value must not be null

  Scenario: CloudWatch log groups should have retention configured
    Given I have aws_cloudwatch_log_group defined
    Then it must contain retention_in_days
    And its value must not be null

  Scenario: CloudWatch log groups should have proper naming
    Given I have aws_cloudwatch_log_group defined
    Then it must contain name
    And its value must not be null

  Scenario: EC2 instances should have detailed monitoring when required
    Given I have aws_instance defined
    When it has tags
    And it contains Environment
    Then it must contain monitoring
    And its value must be true