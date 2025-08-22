Feature: Load balancer security must be properly configured
  In order to ensure secure load balancing
  As a security engineer
  I want to ensure load balancers follow security best practices

  Scenario: ALB should be application type
    Given I have aws_lb defined
    Then it must contain load_balancer_type
    And its value must be application

  Scenario: ALB should not be internal for public-facing applications
    Given I have aws_lb defined
    When it has tags
    And it contains Name
    And its value matches ".*alb.*"
    Then it must contain internal
    And its value must be false

  Scenario: ALB should be deployed across multiple subnets
    Given I have aws_lb defined
    When it contains subnets
    Then it must have more than 1 values

  Scenario: ALB should have security groups configured
    Given I have aws_lb defined
    Then it must contain security_groups
    And its value should reference aws_security_group

  Scenario: ALB target groups should have health checks enabled
    Given I have aws_lb_target_group defined
    When it contains health_check
    Then it must contain enabled
    And its value must be true

  Scenario: ALB target groups should have proper health check configuration
    Given I have aws_lb_target_group defined
    When it contains health_check
    Then it must contain healthy_threshold
    And it must contain unhealthy_threshold
    And it must contain timeout
    And it must contain interval
    And it must contain path

  Scenario: ALB listeners should have proper protocol configuration
    Given I have aws_lb_listener defined
    Then it must contain protocol
    And it must contain port

  Scenario: ALB should have deletion protection in production
    Given I have aws_lb defined
    When it has tags
    And it contains Environment
    And its value is prod
    Then it must contain enable_deletion_protection
    And its value must be true

  Scenario: Target group attachments should reference valid instances
    Given I have aws_lb_target_group_attachment defined
    When it contains target_id
    Then its value should reference aws_instance