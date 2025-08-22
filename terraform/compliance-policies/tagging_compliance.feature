Feature: Resource tagging must follow organizational standards
  In order to ensure proper resource management
  As a DevOps engineer
  I want to ensure all resources have proper tags

  Scenario: All resources should have Project tag
    Given I have any resource defined
    When it supports tags
    Then it must contain tags
    And it must contain Project
    And its value must not be null

  Scenario: All resources should have Environment tag
    Given I have any resource defined
    When it supports tags
    Then it must contain tags
    And it must contain Environment
    And its value must not be null

  Scenario: All resources should have ManagedBy tag
    Given I have any resource defined
    When it supports tags
    Then it must contain tags
    And it must contain ManagedBy
    And its value must be terraform

  Scenario: Production resources should have CriticalSystem tag
    Given I have any resource defined
    When it supports tags
    And it contains tags
    And it contains Environment
    And its value is prod
    Then it must contain CriticalSystem
    And its value must be true

  Scenario: Preview resources should have AutoCleanup tag
    Given I have any resource defined
    When it supports tags
    And it contains tags
    And it contains Environment
    And its value is preview
    Then it must contain AutoCleanup
    And its value must be true

  Scenario: All resources should have Owner tag
    Given I have any resource defined
    When it supports tags
    Then it must contain tags
    And it must contain Owner
    And its value must not be null