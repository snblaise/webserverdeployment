Feature: EC2 instances must use IMDSv2
  In order to improve security
  As a security engineer
  I want to ensure all EC2 instances require IMDSv2

  Scenario: EC2 instances should require IMDSv2
    Given I have aws_instance defined
    When it contains metadata_options
    Then it must contain http_tokens
    And its value must be required
    And it must contain http_put_response_hop_limit
    And its value must be 1

  Scenario: EC2 instances should have metadata endpoint enabled
    Given I have aws_instance defined
    When it contains metadata_options
    Then it must contain http_endpoint
    And its value must be enabled

  Scenario: EC2 instances should enable instance metadata tags
    Given I have aws_instance defined
    When it contains metadata_options
    Then it must contain instance_metadata_tags
    And its value must be enabled