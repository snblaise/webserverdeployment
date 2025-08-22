Feature: EBS volumes must be encrypted
  In order to protect data at rest
  As a security engineer
  I want to ensure all EBS volumes are encrypted

  Scenario: EBS root volumes should be encrypted
    Given I have aws_instance defined
    When it contains root_block_device
    Then it must contain encrypted
    And its value must be true

  Scenario: EBS volumes should use KMS encryption when specified
    Given I have aws_instance defined
    When it contains root_block_device
    And it contains kms_key_id
    Then its value must not be null

  Scenario: EBS volumes should have delete on termination enabled for security
    Given I have aws_instance defined
    When it contains root_block_device
    Then it must contain delete_on_termination
    And its value must be true

  Scenario: EBS volumes should use GP3 volume type for performance
    Given I have aws_instance defined
    When it contains root_block_device
    Then it must contain volume_type
    And its value must be gp3