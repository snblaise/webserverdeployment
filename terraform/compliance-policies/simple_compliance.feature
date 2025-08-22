Feature: Basic infrastructure compliance
  In order to ensure secure infrastructure
  As a security engineer
  I want to validate basic security requirements

  Scenario: EC2 instances must have encrypted EBS volumes
    Given I have aws_instance defined
    When it contains root_block_device
    Then it must contain encrypted
    And its value must be true

  Scenario: EC2 instances must use IMDSv2
    Given I have aws_instance defined
    When it contains metadata_options
    Then it must contain http_tokens
    And its value must be required

  Scenario: Security groups must have descriptions
    Given I have aws_security_group defined
    Then it must contain description
    And its value must not be null

  Scenario: Load balancers must have access logs enabled
    Given I have aws_lb defined
    When it contains access_logs
    Then it must contain enabled
    And its value must be true

  Scenario: IAM roles must have proper assume role policies
    Given I have aws_iam_role defined
    When it contains assume_role_policy
    Then it must contain Version
    And its value must be 2012-10-17