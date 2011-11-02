require 'spec_helper'

describe AMIsController do

  let (:controller) { AMIsController.new }
  let (:ami_name) { "my-ami-#{Time.now.to_i}" }
  let (:puppet_node_name) { "puppet-node-name-#{Time.now.to_i}" }
  let (:prototype_profile_name) { "ami-prototype-#{Time.now.to_i}" }
  let (:ssh) { double('SSH', :run => nil, :upload => nil) }
  let (:server) { double('Server', :id => 'i-12345', :ssh => ssh, :public_ip_address => '127.0.0.1', :create_ami => nil) }
  let (:environment) { double('Environment', :servers => [server], :destroy => nil) }
  let (:ami) { double('AMI', :owner_id => '1234') }
  let (:images) { double('ComputeImages') }

  before { Cloud.stub(:compute => double('Compute', :images => images)) }

  describe '#create' do
    before do
      Profile.stub(:read => nil)
      Environment.stub(:create => environment)
    end
    
    subject { controller.create(ami_name, puppet_node_name, prototype_profile_name) }
    
    it "should create a new environment using the supplied profile" do
      Profile.should_receive(:read).with(prototype_profile_name).and_return('ami_profile')
      Environment.should_receive(:create).with(/#{ami_name}/, 'ami_profile').and_return environment
      subject
    end
    
    # Not all elements of the script are tested - just the important bits
    it "should upload our puppet configuration to the instance" do
      ssh.should_receive(:upload)#.with(File.join(ROOT_DIR, 'puppet'), '/tmp/puppet')
      subject
    end

    it "should run puppet using the node name we specified" do
      ssh.should_receive(:run).with(%r{puppet.+/etc/puppet/manifests/nodes/#{puppet_node_name}.pp})
      subject
    end

    it "should create an AMI from the resulting server" do
      server.should_receive(:create_ami).with(ami_name)
      subject
    end

    it "should finally destroy the environment" do
      environment.should_receive(:destroy)
      subject
    end
  end

  describe :index do
    before { images.stub(:all => [ami]) }
    after { controller.index }

    it "should show an index of the amis" do
      Cloud.should_receive(:account).at_least(1).and_return(double(:account, :aws_user_id => '1234'))
      View.should_receive(:new).at_least(1).and_return(double(:view, :index => true))
      Inform.should_receive(:info).at_least(1)
    end
  end

  describe :show do
    context "AMI doesn't exist" do
      it "should raise error" do
        images.stub(:all => [])
        lambda { controller.show(ami_name) }.should raise_error /not found/i
      end
    end

    context "AMI exists" do
      before { images.stub(:all => [ami]) }
      after { controller.show(ami_name) }

      it "should show the ami" do
        View.should_receive(:new).and_return(double(:view, :show => true))
        Inform.should_receive(:info)
      end
    end
  end

  describe :show do
    context "AMI doesn't exist" do
      it "should raise error" do
        images.stub(:all => [])
        lambda { controller.show(ami_name) }.should raise_error /not found/i
      end
    end

    context "AMI exists" do
      before { images.stub(:all => [ami]) }
      after { controller.show(ami_name) }

      it "should show the ami" do
        View.should_receive(:new).and_return(double(:view, :show => true))
        Inform.should_receive(:info)
      end
    end
  end

  describe :destroy do
    context "AMI doesn't exist" do
      it "should error if the ami doesn't exist" do
        images.stub(:all => [])
        lambda { controller.destroy(ami_name) }.should raise_error /not found/i
      end
    end

    context "AMI exists" do
      before do
        controller.stub(:agree => true)
        images.stub(:all => [ami])
      end

      after { controller.destroy(ami_name, options) }

      context "with no options" do
        let(:options) { {} }

        it "should find an AMI and destroy it if agreement is given" do
          images.should_receive(:all).with('name' => ami_name).and_return([ami])
          ami.should_receive(:deregister)
        end

        it "should ask the user for confirmation before destroying the AMI" do
          controller.should_receive(:agree).and_return(true)
          ami.should_receive(:deregister)
        end

        it "should not destroy the AMI if agreement is not given" do
          controller.should_receive(:agree).and_return(false)
          ami.should_not_receive(:deregister)
        end
      end

      context "with :force => true" do
        let(:options) { { :force => true } }

        it "should not ask for agreement" do
          controller.should_not_receive(:agree)
          ami.should_receive(:deregister)
        end
      end
    end
  end
end
