Given /^I specify the environment profile "([^"]*)"$/ do |profile|
  @profile = profile
end

Given /^I uniquely name my environment$/ do
  @environment_name = unique_test_name 
end

Given /^I uniquely name my AMI$/ do
  @ami_name = unique_test_name
end

Given /^I specify the region "([^"]*)" and account "([^"]*)"$/ do |region, account_name|
  @region = region
  @account_name = account_name
  Cloud.connect(@region, @account_name)
end

Given /^I specify the puppet configuration "([^"]*)"$/ do |puppet_config|
  @puppet_config = puppet_config
end

When /^I run the create\-environment script$/ do
  @log = run_and_capture("./bin/dew --region #{@region} --account #{@account_name} --debug --verbose env create -f #{@profile} #{@environment_name}", "create-environment.#{@profile}")
end

When /^I run the create\-ami script$/ do
  @log = run_and_capture("./bin/dew --region #{@region} --account #{@account_name} --debug --verbose amis create #{@puppet_config} #{@ami_name}", "create-ami")
end

Then /^the script should report success$/ do
  if $?.exitstatus != 0 && File.exist?(@log)
    $stderr.puts File.read(@log)
  end
  $?.exitstatus.should == 0
end

Then /^the script should return an AMI id$/ do
  script_output = File.read(@log)
  script_output.should match(/AMI ID is ([^ ]+)/i)
  script_output =~ /AMI ID is.+(ami-[\w]+)/i # damn matcher won't capture :(
  @ami_id = $1
end

Then /^that AMI should exist as a private AMI in our AWS account$/ do
  ami = Cloud.compute.images.all('name' => @ami_name).first
  @ami_id.should == ami.id
  ami.is_public.should be_false
end

Then /^I should have "([^"]*)" running EC2 servers$/ do |number_of_servers|
  environment.servers.length.should == number_of_servers.to_i
end

Then /^the server names should be prefixed with the environment name$/ do
  server_names = environment.servers.collect { |server| server.tags["Name"] }
  server_names.sort.should == ["#{@environment_name} 1", "#{@environment_name} 2"]
end

Then /^the servers should be in the "([^"]*)" availability zone$/ do |availability_zone|
  environment.servers.each { |server| server.availability_zone.should match /^#{availability_zone}(.*)$/ }
end

Then /^the servers should be tagged with "([^"]*)"$/ do |tag|
  environment.servers.each { |server| server.tags.should have_key tag }
end

Then /^there should be a load balancer in front of the servers$/ do
  servers = elb['Instances']
  
  servers.sort.should == environment.servers.collect { |server| server.id }.sort
end

Then /^I should have an RDS for my environment$/ do
  environment.database.should_not be_nil
end

Then /^I should be able to SSH in to each server using the "([^"]*)" keypair$/ do |keypair|
  environment.servers.each do |server|
    server.ssh.run("echo hello").should == "hello\n"
  end
end

Then /^PUGE database environment variables should be set on each server to match the created RDS$/ do
  environment.servers.each do |server|
    ssh = server.ssh
    %w{DB_NAME DB_USERNAME DB_PASSWORD}.each do |var|
      ssh.run("echo $#{var}").chomp.length.should_not == 0
    end
    ssh.run("echo $DB_HOST").chomp.should == environment.database.public_address
  end
end

Then /^I should be able to connect to the RDS$/ do
  environment.servers.each do |server|
    ssh = server.ssh
    #host.run("nc -w 1 $DB_HOST 3306 > /dev/null 2>&1 ; echo $?").chomp.should == "0"
    ssh.run("sudo apt-get install -y mysql-client", :quiet_stderr => true)
    ssh.run("echo show databases | mysql -u$DB_USERNAME -p$DB_PASSWORD -h$DB_HOST").chomp.length.should_not == 0
  end
end
