Feature: Creating a new AMI

  As PlayUp
  I want new AMIs to be created from Puppet configurations
  So that I can use those AMIs to create new environments

  @aws
  @slow
  @disabled
  Scenario: Creating a new AMI from a puppet configuration
    Given I specify the puppet configuration "blank"
    And I uniquely name my AMI
    And I specify the region "ap-southeast-1" and account "development"
    When I run the create-ami script
    Then the script should report success
    And the script should return an AMI id
    And that AMI should exist as a private AMI in our AWS account