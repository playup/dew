Feature: Creating a new environment

  As PlayUp
  I want new environments to be provisioned automatically
  So that I can deploy applications to those environments

  @aws
  Scenario: Creating a new light environment using the development account
    Given I specify the environment profile "test-light"
    And I uniquely name my environment
    And I specify the region "ap-southeast-1" and account "development"
    When I run the create-environment script
    Then the script should report success
    And I should have "2" running EC2 servers
    And the server names should be prefixed with the environment name
    And the servers should be in the "ap-southeast" availability zone
    And the servers should be tagged with "Name"
    And the servers should be tagged with "Environment"
    And the servers should be tagged with "Creator"
    And I should be able to SSH in to each server using the "devops" keypair
    And there should be a load balancer in front of the servers

  @slow
  @aws
  Scenario Outline: Creating a new full environment
    Given I specify the environment profile "test-full"
    And I uniquely name my environment
    And I specify the region "<region>" and account "development"
    When I run the create-environment script
    Then the script should report success
    And I should have "2" running EC2 servers
    And the server names should be prefixed with the environment name
    And the servers should be in the "<region>" availability zone
    And the servers should be tagged with "Name"
    And the servers should be tagged with "Environment"
    And the servers should be tagged with "Creator"
    And I should be able to SSH in to each server using the "devops" keypair
    And there should be a load balancer in front of the servers
    And I should have an RDS for my environment
    And PUGE database environment variables should be set on each server to match the created RDS
    And I should be able to connect to the RDS

    Scenarios: regions
      | region         |
      | ap-southeast-1 |
      | eu-west-1      |