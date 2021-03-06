require 'spec_helper'

describe Environment do

  let (:name) { 'my-environment' }
#  let (:server) { double('Server', :id => 'i-12345', :add_tag => nil, :wait_until_ready => nil, :availability_zone => 'ap-southeast-1') }
  let(:groups) { %w(non_default) }
  let (:server) { double('Server', :id => 'i-12345', :add_tag => nil, :wait_until_ready => nil, :availability_zone => 'ap-southeast-1', :groups => groups) }
  let (:servers) { [] }
  let(:an_elb) { double('elb1', :id => 'my-environment') }
  let (:elb) { double('ELB', :load_balancers => [an_elb]) }
  let (:database) { double('Database') }
  let(:keypair_available_in_aws) { true }
  let(:profile_count) { 2 }
  
  let(:instance_disk_size) { rand(234) }
  let(:database) { mock('Database', :destroy => true, :wait_until_ready => true) }
  
  let(:environment) { Environment.new(name, servers, database) }    

  before :each do
    Cloud.connect(name, 'development')
    Cloud.stub(:elb => elb, :keypair_exists? => keypair_available_in_aws)
  end

  describe "initialization" do
    subject { environment }

    its(:name) { should == name }
    its(:servers) { should == [] }
    its(:database) { should == database }
  end
  
  describe "::get" do
    before :each do
      Server.stub(:find => [])
      Database.stub(:get => nil)
    end
    it "should discover servers belonging to this environment" do
      Server.should_receive(:find).with('Environment', name).and_return [server]
      Environment.get(name).servers.should == [server]
    end
    it "should discover a database belonging to this environment" do
      Database.should_receive(:get).with(name).and_return 'database'
      Environment.get(name).database.should == 'database'
    end
    it "should return nil if no servers nor database is discovered for this environment" do
      Environment.get(name).should == nil
    end
  end

  describe "::create" do
    let (:profile) do
      double('Profile',
        :username => 'username',
        :security_groups => %w(default),
        :ami => 'ami-12345', :size => 'm1.large',
        :keypair => 'devops', :count => profile_count,
        :has_rds? => false, :has_elb? => false,
        :instance_disk_size => instance_disk_size,
        :instance_disk_size? => !!instance_disk_size
      )
    end
  
    subject { Environment.create(name, profile) }
  
    context "when environment name is invalid" do
      let(:name) { 'my_bad_name' }
      
      it "should raise an error" do
        lambda { subject }.should raise_error(ArgumentError, /does not match/)
      end
    end

    context "when profile keypair is not available in AWS" do
      let(:keypair_available_in_aws) { false }

      it "should raise an error" do
        lambda { subject }.should raise_error /is not available/
      end
    end
    
    context "when no instance disk size is specified" do
      let(:instance_disk_size) { nil }
      let(:environment) { mock(:add_server => true, :wait_until_ready => true) }
      
      before do
        Environment.stub(:new => environment)
      end
      
      it "should not resize_disks on the environment" do
        environment.should_not_receive(:resize_disks)
        subject
      end
    end

    context "when profile keypair is available in AWS" do

      let(:environment) { double(:environment, :name => name, :add_database => true, :wait_until_ready => true, :add_server => true, :resize_disks => true) }

      before do
        Environment.stub(:new => environment)
      end

      after { Environment.create(name, profile) }

      context "with a profile count of 2" do
        let(:profile_count) { 2 }

        it "should add two instances to that environment with the chosen AMI, size and keypair" do
          environment.should_receive(:add_server).with(
            profile.username,
            :ami => profile.ami, 
            :size => profile.size,
            :keypair => profile.keypair,
            :groups => profile.security_groups,
            :disk_size => profile.instance_disk_size
          ).twice
        end
      end

      it "should wait for our environment to become ready" do
        environment.should_receive(:wait_until_ready)
      end

      describe "with an ELB specified in the profile" do
        before :each do
          profile.stub(:has_elb? => true, :elb_listener_ports => [80])
        end

        it "should add an ELB to the environment with the required ports" do
          environment.should_receive(:add_elb).with([80])
        end
      end

      describe "with an RDS specified in the profile" do
        before :each do
          profile.stub(:has_rds? => true, :rds_size => 'db.m1.small', :rds_storage_size => 5)
          environment.stub(:add_database => nil, :configure_servers_for_database => nil)
          Password.stub(:random => 'abcdef')
        end

        it "should add an RDS to the environment with the required size and a random password" do
          environment.should_receive(:add_database).with('db.m1.small', 5, 'abcdef')
        end

        it "should ask the environment to update the database configuration on the servers" do
          environment.should_receive(:configure_servers_for_database).with('abcdef')
        end
      end

    end
  end

  describe "::owners" do
    before do
      Cloud.should_receive(:valid_servers).at_least(1).and_return( [
        double(:server, :tags => {"Environment" => "test-1", "Creator" => "chris" }),
        double(:server, :tags => {"Environment" => "test-2", "Creator" => "ash"   })
      ])
    end

    it { Environment.owners.should == [{:name=>"test-1", :owner=>"chris"}, {:name=>"test-2", :owner=>"ash"}] }
  end

  describe "::index" do
    before {
      Cloud.should_receive(:valid_servers).at_least(1).and_return( [
        double(:server, :tags => {"Environment" => "test-1", "Creator" => "chris" }),
        double(:server, :tags => {"Environment" => "test-2", "Creator" => "ash"   })
      ])
    }
    after { Environment.index }

    # TODO: Have the model return what is to be displayed rather than display it itself.
    it "should index the environments" do
      Inform.should_receive(:info).at_least(1).with( <<EOF
Environments:
  +----------+---------+
  | name     | owner   |
  +----------+---------+
  | "test-1" | "chris" |
  | "test-2" | "ash"   |
  +----------+---------+
EOF
      )
    end
  end

  describe '#show' do
    before do
      Cloud.stub_chain(:account, :aws_user_id).and_return('12345')
    end
    
    subject { environment.show }

    context "with servers" do
      let(:servers) { [server] }
      let(:database) { nil }
      
      before { environment.stub(:elb => nil) }
      it "should show the servers" do
        View.should_receive(:new).with(
          "SERVERS", [server], %w(id flavor_id public_ip_address state created_at groups key_name availability_zone creator)
        ).and_return(double(:servers_view, :index => 'servers'))
        subject
      end
    end

    context "with an elb" do
      let(:database) { nil }

      it "should show the elb" do
        elb_view = double(:elb_view)
        View.should_receive(:new).with(
          "ELB", [an_elb], %w(created_at dns_name instances availability_zones)
        ).and_return(elb_view)
        elb_view.should_receive(:show).and_return('stuff')
        subject
      end
    end

    context "with a database" do
      before { environment.stub(:elb => nil) }

      it "should show the database" do
        View.should_receive(:new).with(
          "DATABASE", [database], %w(flavor_id state created_at availability_zone db_security_groups)
        ).and_return(mock('database_view', :index => 'database', :show => "some_ stuff"))
        subject
      end
    end

  end

  describe '#destroy' do
    subject { environment.destroy }
  
    before do
      environment.stub(:has_elb? => false)
    end
    
    it "should destroy the database if there is one" do
      environment.stub(:database => database)
      database.should_receive(:destroy)
      
      subject
    end
    it "should destroy the servers if there are any" do
      environment.stub(:servers => [server])
      server.should_receive(:destroy)

      subject
    end

    it "should destroy the ELB if there is one" do
      environment.stub(:has_elb? => true)
      elb.should_receive(:delete_load_balancer).with(name)

      subject
    end
  end

  describe '#add_server' do
    let(:create_options) { mock('create options') }
    let(:username) { 'username' }

    subject { environment.add_server(username, create_options) }
    
    before :each do
      Server.stub(:create!).and_return(server)
    end

    it "should create a Server from the provided ami, size and keypair" do
      Server.should_receive(:create!).with(create_options)
      subject
    end

    it "should add the Server to its servers array" do
      # don't use subject here, is memoized
      environment.add_server(username, create_options)
      environment.add_server(username, create_options)
      environment.servers.should == [server, server]
    end

    it "should tag the server with the environment name, creator and username" do
      server.should_receive(:add_tag).with('Environment', name)
      server.should_receive(:add_tag).with('Creator', ENV['USER'])
      server.should_receive(:add_tag).with('Username', 'username')
      subject
    end

    it "should tag the server with an indexed name" do
      server.should_receive(:add_tag).with('Name', "#{name} 1")
      environment.add_server('username', create_options)

      server.should_receive(:add_tag).with('Name', "#{name} 2")
      environment.add_server('username', create_options)
    end
  end

  describe '#remove_server_from_elb' do
    subject { environment.remove_server_from_elb(server) }
    
    it "should remove the server from the ELB" do
      elb.should_receive(:deregister_instances_from_load_balancer).with([server.id], name)
      subject
    end
  end
  
  describe '#add_server_to_elb' do
    subject { environment.add_server_to_elb(server) }
    
    it "should add the server to the ELB" do
      elb.should_receive(:register_instances_with_load_balancer).with([server.id], name)
      subject
    end
  end

  context "with one server" do

    before do
      environment.stub(:servers => [server])
    end

    describe :add_elb do
      before :each do
        server.stub(:availability_zone => 'ap-southeast-1a')
        elb.stub(:create_load_balancer => nil, :register_instances_with_load_balancer => nil)
      end
      it "should create the ELB using the provided listeners, environment name and the availability zones of the current servers" do
        server.should_receive(:availability_zone).and_return('ap-southeast-1a')

        elb.should_receive(:create_load_balancer).with(
            ['ap-southeast-1a'], name,
            [{'Protocol' => 'TCP', 'LoadBalancerPort' => 80, 'InstancePort' => 80}]
        )
        environment.add_elb [80]
      end
      it "should add the servers to the elb" do
        elb.should_receive(:register_instances_with_load_balancer).with([server.id], name)
        environment.add_elb [80]
      end

    end

    describe :add_database do
      before do
        Database.stub(:create! => database)
      end

      let(:storage_size) { rand(234) }

      it "should create an RDS of the requested size, using the environment name and a random password" do
        Database.should_receive(:create!).with(name, 'db.m1.small', storage_size, 'password')
        environment.add_database 'db.m1.small', storage_size, 'password'
      end

      it "should make the database available on the 'database' accessor" do
        environment.add_database 'db.m1.small', storage_size, 'password'
        environment.database.should == database
      end
    end

    describe :wait_until_ready do
      before {
        Cloud.stub(:security_groups => { 'non_default' => double(:group, :ip_permissions => ip_permissions) } )
      }
      after { environment.wait_until_ready }

      context "with no ip_permissions" do
        let(:ip_permissions) { [:some_ip_permissions] }

        it "should wait for each server to be ready" do
          server.should_receive(:wait_until_ready)
        end
      end

      context "with ip_permissions" do
        let(:ip_permissions) { [] }

        it "should not wait for each server to be ready" do
          server.should_not_receive(:wait_until_ready)
        end
      end
    end

    context "with an RDS" do
      before :each do
        Cloud.stub(:security_groups => { 'non_default' => double(:group, :ip_permissions => true) } )
        environment.stub(:database => database)
      end

      describe :wait_until_ready do
        it "should wait for the database to be ready" do
          database.should_receive(:wait_until_ready)
          environment.wait_until_ready
        end
      end

      describe :configure_servers_for_database do
        it "should ask each server to apply credentials from our database" do
          server.should_receive(:configure_for_database).with(database, 'password')
          environment.configure_servers_for_database 'password'
        end
      end

    end
  end

  def mock_describe_load_balancers load_balancers, name=nil
    response = double('ELB Response', :body => { 'DescribeLoadBalancersResult' => { 'LoadBalancerDescriptions' => load_balancers }})
    if name
      elb.should_receive(:describe_load_balancers).with(name).and_return(response)
    else
      elb.should_receive(:describe_load_balancers).and_return(response)
    end
  end

  describe '#has_elb?' do
    subject { environment.has_elb? }
  
    it "return true if we have a load balancer" do
      mock_describe_load_balancers([{'LoadBalancerName' => name}])
      subject.should be_true
    end

    it "return false if we don't" do
      mock_describe_load_balancers([{'LoadBalancerName' => "XXXX"}])
      subject.should be_false
    end

  end
  
  describe "#show_json" do
    let(:servers) { [mock(:dns_name => 'fish.com', :public_ip_address => '1.2.3.4'), mock(:dns_name => 'fish2.com', :public_ip_address => '1.2.3.5')] }
    let(:output) { servers.map { |s| { 'public_dns' => s.dns_name, 'public_ip' => s.public_ip_address } } }
    
    subject { environment.show_json }
  
    it "should return the correct JSON" do
      STDOUT.should_receive(:puts).with(JSON.pretty_generate(output))
      subject
    end
  end
  
  describe '#resize_disks' do
  
    let(:servers) { [mock('server1'), mock('server2')] }  

    subject { environment.resize_disks }
  
    it "should resize_disk on each server" do
      servers.each { |s| s.should_receive(:resize_disk).with() }
      subject
    end
  
  end

end
