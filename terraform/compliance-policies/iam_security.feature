Feature: IAM roles and policies must follow security best practices
  In order to ensure least privilege access
  As a security engineer
  I want to ensure IAM configurations follow security best practices

  Scenario: IAM roles should have proper assume role policies
    Given I have aws_iam_role defined
    When it contains assume_role_policy
    Then it must contain Version
    And its value must be 2012-10-17

  Scenario: EC2 IAM roles should only allow EC2 service to assume
    Given I have aws_iam_role defined
    When it contains assume_role_policy
    Then it must contain Statement
    And it must contain Principal
    And it must contain Service
    And its value must be ec2.amazonaws.com

  Scenario: IAM instance profiles should reference valid roles
    Given I have aws_iam_instance_profile defined
    When it contains role
    Then its value must not be null

  Scenario: IAM role policy attachments should reference valid roles
    Given I have aws_iam_role_policy_attachment defined
    When it contains policy_arn
    Then it must contain role
    And its value must not be null

  Scenario: Custom IAM policies should have proper version
    Given I have aws_iam_policy defined
    When it contains policy
    Then it must contain Version
    And its value must be 2012-10-17

  Scenario: Custom IAM policies should not allow wildcard actions on all resources
    Given I have aws_iam_policy defined
    When it contains policy
    And it contains Statement
    And it contains Action
    And its value is "*"
    And it contains Resource
    And its value is "*"
    Then it must fail

  Scenario: IAM policies should have proper naming convention
    Given I have aws_iam_policy defined
    Then it must contain name_prefix
    And its value must not be null