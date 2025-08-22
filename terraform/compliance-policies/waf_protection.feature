Feature: WAF protection must be enabled
  In order to protect against web attacks
  As a security engineer
  I want to ensure WAF is properly configured

  Scenario: WAF Web ACL should be associated with ALB
    Given I have aws_wafv2_web_acl_association defined
    When it contains resource_arn
    Then its value must not be null

  Scenario: WAF Web ACL should have managed rules
    Given I have aws_wafv2_web_acl defined
    When it contains rule
    Then it must contain statement
    And it must contain managed_rule_group_statement

  Scenario: WAF should have rate limiting
    Given I have aws_wafv2_web_acl defined
    When it contains rule
    Then it must contain statement
    And it must contain rate_based_statement

  Scenario: WAF Web ACL should have CloudWatch metrics enabled
    Given I have aws_wafv2_web_acl defined
    When it contains visibility_config
    Then it must contain cloudwatch_metrics_enabled
    And its value must be true

  Scenario: WAF Web ACL should have sampled requests enabled
    Given I have aws_wafv2_web_acl defined
    When it contains visibility_config
    Then it must contain sampled_requests_enabled
    And its value must be true

  Scenario: WAF Web ACL should be regional scope
    Given I have aws_wafv2_web_acl defined
    Then it must contain scope
    And its value must be REGIONAL

  Scenario: WAF Web ACL should have default allow action
    Given I have aws_wafv2_web_acl defined
    When it contains default_action
    Then it must contain allow

  Scenario: WAF should have logging configuration
    Given I have aws_wafv2_web_acl_logging_configuration defined
    When it contains resource_arn
    Then its value must not be null

  Scenario: WAF logging should use CloudWatch
    Given I have aws_wafv2_web_acl_logging_configuration defined
    When it contains log_destination_configs
    Then its value must not be null