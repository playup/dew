Given /^an environment that PUGE can be deployed to$/ do
  Given 'I specify the environment profile "puge-deploy"'
  And "I uniquely name my environment"
  And 'I specify the region "ap-southeast-1" and account "development"'
end

Given /^I specify the Git PUGE tag "([^"]*)"$/ do |tag|
  @tag = tag
end

When /^I run the deployment script$/ do
  @log = run_and_capture("script/deploy.rb puge --region #{Cloud.region} --account #{Cloud.account_name} #{@tag} #{@environment_name} development", "deploy")
  sleep 60    # wait for tomcat to restart
end

Then /^I should see the correct PUGE tag has been deployed when I hit the load balancer$/ do
  require 'net/http'

  http = Net::HTTP.new(elb['DNSName'], 80)
  http.read_timeout = 60

  response = http.start do |web|
    web.request(Net::HTTP::Get.new('/admin'))
  end

  response.body.should =~ /Revision: \w{7} /
end