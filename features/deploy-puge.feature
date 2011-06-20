Feature: Deploying Puge to an environment

 As PlayUp
 I want to deploy Puge to a new environment
 So that I can test it

 @wip
 @aws
 @slow
 Scenario: Deploying Puge from Gitub to a new environment
   Given an environment that PUGE can be deployed to
   And I run the create-environment script
   And I specify the Git PUGE tag "master"
   When I run the deployment script
   Then the script should report success
   And I should see the correct PUGE tag has been deployed when I hit the load balancer
