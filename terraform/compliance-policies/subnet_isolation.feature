Feature: Network isolation must be properly configured
  In order to ensure network isolation
  As a security engineer
  I want to ensure proper subnet placement and network isolation

  Scenario: EC2 instances should not have public IPs
    Given I have aws_instance defined
    Then it must not contain associate_public_ip_address
    Or its value must be false

  Scenario: EC2 instances should be placed in private subnets
    Given I have aws_instance defined
    When it contains subnet_id
    Then its value must not match ".*public.*"

  Scenario: ALB should be internet-facing and in public subnets
    Given I have aws_lb defined
    When it contains internal
    Then its value must be false

  Scenario: NAT Gateway should be in public subnets
    Given I have aws_nat_gateway defined
    When it contains subnet_id
    Then its value should reference public subnets

  Scenario: Private subnets should not auto-assign public IPs
    Given I have aws_subnet defined
    When it has tags
    And it contains Name
    And its value matches ".*private.*"
    Then it must contain map_public_ip_on_launch
    And its value must be false

  Scenario: Public subnets should auto-assign public IPs
    Given I have aws_subnet defined
    When it has tags
    And it contains Name
    And its value matches ".*public.*"
    Then it must contain map_public_ip_on_launch
    And its value must be true

  Scenario: VPC should have DNS hostnames enabled
    Given I have aws_vpc defined
    Then it must contain enable_dns_hostnames
    And its value must be true

  Scenario: VPC should have DNS support enabled
    Given I have aws_vpc defined
    Then it must contain enable_dns_support
    And its value must be true

  Scenario: VPC endpoints should be in private subnets
    Given I have aws_vpc_endpoint defined
    When it contains vpc_endpoint_type
    And its value is Interface
    Then it must contain subnet_ids
    And its value should reference private subnets

  Scenario: VPC endpoints should have private DNS enabled
    Given I have aws_vpc_endpoint defined
    When it contains vpc_endpoint_type
    And its value is Interface
    Then it must contain private_dns_enabled
    And its value must be true