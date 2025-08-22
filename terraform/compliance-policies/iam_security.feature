Feature: IAM roles and policies must follow security best practices
  In order to ensure least privilege access
  As a security engineer
  I want to ensure IAM configurations follow security best practices

  Scenario: IAM roles should have proper assume role policies
    Given I have aws_iam_role defined
    When it contains assume_role_policy
    Then it must contain Version
    And its value must be 2012-10-17

  Scenario: IAM instance profiles should reference valid roles
    Given I have aws_iam_instance_profile defined
    When it contains role
    Then its value must not be null

  Scenario: IAM role policy attachments should reference valid roles
    Given I have aws_iam_role_policy_attachment defined
    When it contains policy_arn
    Then it must contain role
    And its value must not be null