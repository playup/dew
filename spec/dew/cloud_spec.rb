require 'spec_helper'

describe :Cloud do
  
  let (:region) { 'ap-southeast-1' }
  let (:account_name) { 'development' }
  let (:profile_name) { 'test-light' }

  let (:aws_credentials) { {:aws_access_key_id => '1234', :aws_secret_access_key => '5678', :region => region} }
  let (:root_aws_credentials) { aws_credentials.merge(:provider => 'AWS') }
  let (:account) { double('Account', aws_credentials.merge(:has_dns? => false)) }
  let (:profile) { double('Profile') }
  
  context "after connect is called" do
    before :each do
      Account.stub(:read => account)
      Cloud.connect(region, account_name, profile_name)
    end
    
    it { Cloud.region.should == region }
    it { Cloud.account_name.should == account_name }
    it { Cloud.profile_name.should == profile_name }

    it "should provide the Account" do
      Account.should_receive(:read).with(account_name).and_return(account)
      Cloud.account.should == account
    end
    
    it "should provide the Profile" do
      Profile.should_receive(:read).with(profile_name).and_return(profile)
      Cloud.profile.should == profile
    end
    
    it "should provide a compute hook" do
      Fog::Compute.should_receive(:new).with(root_aws_credentials).and_return('compute')
      Cloud.compute.should == 'compute'
    end

    it "should provide a security groups hook" do
      security_group = double(:security_group, :name => 'foo')
      Fog::Compute.should_receive(:new).with(root_aws_credentials).and_return(double(:compute, :security_groups => [security_group]))
      Cloud.security_groups.should == { 'foo' => security_group }
    end

    it "should return valid servers" do
      servers = [
        double(:server, :state => 'running'),
        double(:server, :state => 'terminated'),
        double(:server, :state => 'pending')
      ]
      Cloud.stub_chain(:compute, :servers).and_return( servers )
      Cloud.valid_servers.should == [servers[0], servers[2]]
    end

    it "should check AWS to ensure the given keypair exists" do
      Fog::Compute.should_receive(:new).with(root_aws_credentials).and_return(
        double(:compute, :key_pairs => mock(:some_key_pairs, :get => true))
      )
      Cloud.keypair_exists?('a_keypair').should be_true
    end

    it "should provide an ELB hook" do
      Fog::AWS::ELB.should_receive(:new).with(aws_credentials).and_return('elb')
      Cloud.elb.should == 'elb'
    end
    
    it "should provide an RDS hook" do
      Fog::AWS::RDS.should_receive(:new).with(aws_credentials).and_return('rds')
      Cloud.rds.should == 'rds'
    end

    # TODO: should this be here?
    it "should provide a hook to the rds_authorized_ec2_owner_ids" do
      Fog::AWS::RDS.should_receive(:new).with(aws_credentials).and_return(
        double(:rds, :security_groups => [ double(:security_group, :id => 'default', :ec2_security_groups => [
          { "EC2SecurityGroupName" => "default", "Status" => "authorized", "EC2SecurityGroupOwnerId" => '12345' }
        ]) ])
      )
      Cloud.rds_authorized_ec2_owner_ids.should == ['12345']
    end
    
    describe :keyfile_path do
      it "should look for the keypair in the ~/.dew/accounts directory" do
        Cloud.connect(region, account_name)
        Cloud.keyfile_path('devops').should == "#{ENV['HOME']}/.dew/accounts/keys/#{account_name}/#{region}/devops.pem"
      end
    end
    
    it { Cloud.has_dns?.should be_false }
    
    context "with DNS credentials in the account" do
      before :each do
        account.stub(:has_dns? => true)
      end
      it { Cloud.has_dns?.should be_true }
      
      it "should provide an OpenSRS DNS handle" do
        pending
        # Cloud.account.should_receive(:opensrs_credentials).and_return('opensrs creds')
        # OpenSRS::Server.should_receive(:new).with('opensrs creds').and_return('server')
        # Cloud.dns.should == 'server'
      end
    end
  end
end
