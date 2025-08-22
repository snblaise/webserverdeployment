Feature: Security groups must follow least privilege
  In order to minimize attack surface
  As a security engineer
  I want to ensure security groups follow least privilege principles

  Scenario: Security groups should not allow unrestricted SSH access
    Given I have aws_security_group defined
    When it contains ingress
    And it contains from_port
    And its value is 22
    And it contains cidr_blocks
    Then its value must not be "0.0.0.0/0"

  Scenario: Security groups should not allow unrestricted RDP access
    Given I have aws_security_group defined
    When it contains ingress
    And it contains from_port
    And its value is 3389
    And it contains cidr_blocks
    Then its value must not be "0.0.0.0/0"

  Scenario: Security groups should not allow unrestricted HTTP access from internet
    Given I have aws_security_group defined
    When it has tags
    And it contains Name
    And its value matches ".*ec2.*"
    When it contains ingress
    And it contains from_port
    And its value is 80
    And it contains cidr_blocks
    And its value is "0.0.0.0/0"
    Then it must fail

  Scenario: EC2 security groups should only accept traffic from ALB
    Given I have aws_security_group defined
    When it has tags
    And it contains Name
    And its value matches ".*ec2.*"
    When it contains ingress
    And it contains from_port
    And its value is 80
    Then it must contain security_groups
    And it must not contain cidr_blocks

  Scenario: ALB security groups should only allow HTTP from allowed CIDRs
    Given I have aws_security_group defined
    When it has tags
    And it contains Name
    And its value matches ".*alb.*"
    When it contains ingress
    And it contains from_port
    And its value is 80
    Then it must contain cidr_blocks
    And its value must not be "0.0.0.0/0"

  Scenario: Security groups should have proper lifecycle management
    Given I have aws_security_group defined
    Then it must contain lifecycle
    And it must contain create_before_destroy
    And its value must be true

  Scenario: VPC endpoint security groups should only allow HTTPS from VPC
    Given I have aws_security_group defined
    When it has tags
    And it contains Name
    And its value matches ".*vpc-endpoints.*"
    When it contains ingress
    And it contains from_port
    And its value is 443
    Then it must contain cidr_blocks
    And its value must not be "0.0.0.0/0"