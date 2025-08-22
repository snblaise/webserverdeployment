Feature: Patch management must be properly configured
  In order to ensure systems are kept up to date
  As a security engineer
  I want to ensure patch management is properly configured

  Scenario: SSM patch baseline should be configured for Amazon Linux
    Given I have aws_ssm_patch_baseline defined
    When it contains operating_system
    Then its value must be AMAZON_LINUX_2023

  Scenario: SSM patch baseline should include security patches
    Given I have aws_ssm_patch_baseline defined
    When it contains approval_rule
    And it contains patch_filter
    And it contains key
    And its value is CLASSIFICATION
    Then it must contain values
    And its value must contain Security

  Scenario: SSM patch baseline should have proper naming
    Given I have aws_ssm_patch_baseline defined
    Then it must contain name
    And its value must not be null

  Scenario: SSM patch groups should be configured
    Given I have aws_ssm_patch_group defined
    When it contains baseline_id
    Then its value must not be null

  Scenario: State Manager associations should use proper documents
    Given I have aws_ssm_association defined
    When it contains name
    Then its value must be AWS-RunPatchBaseline

  Scenario: State Manager associations should have schedule configured
    Given I have aws_ssm_association defined
    Then it must contain schedule_expression
    And its value must not be null

  Scenario: State Manager associations should target patch groups
    Given I have aws_ssm_association defined
    When it contains targets
    Then it must contain key
    And its value must be tag:Patch Group

  Scenario: EC2 instances should have patch group tags
    Given I have aws_instance defined
    When it contains tags
    Then it must contain "Patch Group"
    And its value must not be null