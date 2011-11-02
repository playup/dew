require 'spec_helper'

describe Server do

  let (:compute) { double('Compute', :servers => double('ComputeServers'), :images => double('ComputeImages'), :tags => double('ComputeTags')) }
  let (:id) { 'i-12345' }
  let (:endpoint) { '10.4.5.6' }
  let (:key_name) { 'mykey'}
  let (:fog_server) { double('FogServer', :id => id, :public_ip_address => endpoint, :key_name => key_name, :state => 'running', :tags => { 'Creator' => 'foo'} )}

  before :each do
    compute.servers.stub(:create => fog_server)
    Cloud.stub(:compute => compute)  
  end

  describe ".create!" do
    it "should ask Fog to create a new server with the provided AMI, size and keypair" do
      compute.servers.should_receive(:create).with(:image_id => 'ami', :flavor_id => 'size', :key_name => key_name, :groups => %(non_default))
      Server.create!('ami', 'size', key_name, %(non_default))
    end

    it "should return a new server object with an ID" do
      server = Server.create!('ami', 'size', key_name, %(non_default))
      server.id.should == id
    end
  end

  describe ".find" do
    it "should return an instance for each server return from fog matching our tag" do
      compute.servers.should_receive(:all).with('tag:Environment' => 'hello').and_return([fog_server])
      Server.should_receive(:new).with(fog_server).and_return('server')
      Server.find('Environment', 'hello').should == ['server']
    end
      
    it "should filter out servers that are not running or pending" do
      terminated_fog_server = double('Terminated Fog Server', :state => 'terminated')
      Server.should_receive(:new).with(fog_server).and_return('server')
      compute.servers.stub(:all => [fog_server, terminated_fog_server])
      Server.find('Environment', 'hello').should == ['server']
    end
  end

  context "with an already created server" do
    let (:ssh) { double('SSH') }

    before :each do
      @server = Server.create!('ami', 'size', key_name, %(non_default))
      Gofer::Host.stub(:new => ssh)
      Cloud.stub(:keyfile_path => '')
      File.stub(:read => nil)
    end

    describe :username do
      context "with a username tag" do
        before :each do
          fog_server.should_receive(:tags).and_return({'Username' => 'bob'})
        end
        
        it "should use the username in the tag" do
          @server.username.should == 'bob'
        end
      end
      
      it "should default to 'ubuntu' if no Username tag is present" do
        @server.username.should == 'ubuntu'
      end
    end

    describe :creator do
      it "should return the creator from the fog_object's tags" do
        @server.creator.should == 'foo'
      end
    end

    describe :add_tag do
      it "should ask our compute handler to tag an instance with each key value pair provided" do
        compute.tags.should_receive(:create).with(:resource_id => id, :key => 'A', :value => 'b')
        @server.add_tag('A', 'b')
      end
    end

    describe :credentials do
      context "server has no key" do
        let(:key_name) { nil }

        it { @server.credentials.should be_false }
      end

      context "server has a key" do
        before do
          @path = '/key/path'
          Cloud.should_receive(:keyfile_path).with(key_name).and_return(@path)
        end

        context "key file exists" do
          let(:file_stat) { double(:stat, :mode => 600, :uid => Process.euid) }
          before do
            File.should_receive(:stat).with(@path).and_return(file_stat)
            File.should_receive(:chmod).with(0600, @path).and_return(true)
          end

          it { @server.credentials.should == "-i /key/path -o Port=22 -o StrictHostKeyChecking=no ubuntu@10.4.5.6" }
        end

        context "key file does not exist" do
          let(:file_stat) { double(:stat, :mode => 600, :uid => Process.euid) }
          before do
            File.should_receive(:stat).with(@path).and_raise(Errno::ENOENT)
          end

          it { lambda { @server.credentials }.should raise_error %r{Can't find keyfile} }
        end
      end
    end

    it "should delegate some methods to our fog object" do
      %w{availability_zone public_ip_address}.each do |method_name|
        fog_server.should_receive(method_name).with('args').and_return('hello')
        @server.send(method_name, 'args').should == 'hello'
      end
    end

    # TODO: AMI should be refactored out in to its own class.
    describe :create_ami do
      let (:ami_name) { 'my-new-ami' }
      let (:ami) { double('AMI', :id => 'ami-12345', :wait_for => nil)}
      let (:ami_create_response) {double('response', :body => {'imageId' => ami.id})}

      before :each do
        compute.stub(:create_image => ami_create_response)
        compute.images.stub(:get => ami)
        Account.stub(:user_ids => [])
      end

      after :each do
        @server.create_ami ami_name
      end

      it "should create an AMI from the server image" do
        compute.should_receive(:create_image).with(@server.id, ami_name, //).and_return(ami_create_response)
        compute.images.should_receive(:get).with(ami.id).and_return(ami)
      end

      it "should wait for the AMI to become ready" do
        ami.should_receive(:wait_for)
      end

      it "should share the AMI with the other known accounts" do
        Account.should_receive(:user_ids).and_return(['11', '22'])
        compute.should_receive(:modify_image_attributes).with(ami.id, 'launchPermission', 'add', 'UserId' => '11')
        compute.should_receive(:modify_image_attributes).with(ami.id, 'launchPermission', 'add', 'UserId' => '22')
      end

    end

    describe :ssh do
      it "should open a new Gofer::Host connection using the hostname, default username and key data" do
        Cloud.should_receive(:keyfile_path).with(key_name).and_return('/key/path')
        File.should_receive(:read).with('/key/path').and_return('key data')
        Gofer::Host.should_receive(:new).with(endpoint, @server.username, hash_including(:key_data => ['key data'])).and_return 'ssh'
        @server.ssh.should == 'ssh'
      end
    end

    describe :configure_for_database do
      it "should open up an SSH connection and populate /etc/environment with database credentials" do
        database = double('Database')
        database.should_receive(:db_environment_file).with('password').and_return('environment file contents')
        ssh.should_receive(:write).with('environment file contents', '/tmp/envfile')
        ssh.should_receive(:run).with('sudo mv /tmp/envfile /etc/environment')
        @server.configure_for_database database, 'password'
      end
    end

    describe :wait_until_ready do
      let (:gofer) { double('Gofer::Host') }

      before :each do
        fog_server.stub(:wait_for => nil)
        Gofer::Host.stub(:new).and_return(gofer)
      end

      context "with SSH responding correctly" do
        it "should return successfully" do
          gofer.should_receive(:run)
          @server.wait_until_ready
        end
      end

      context "with SSH timing out" do
        it "should return the underlying error" do
          # Use a very low timeout to avoid the test taking forever.
          gofer.should_receive(:run).at_least(1).and_raise Timeout::Error
          lambda {@server.wait_until_ready(1)}.should raise_error /SSH Timeout/
        end
      end

    end
  end
end
