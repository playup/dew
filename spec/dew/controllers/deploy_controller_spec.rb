require File.expand_path(File.join(File.dirname(__FILE__), '../spec_helper'))

describe DeployController do

  let (:type) { 'puge' }
  let (:tag) { 'puge-1.16.1' }
  let (:rails_env) { 'development' }
  let (:environment_name) { 'myenvironment' }
  let (:opts) { { 'tag' => tag, 'rails_env' => rails_env } }

  describe :create do
    before :each do
      @servers = []
      (0..1).each { @servers << double('Server').as_null_object }
      @server = @servers.first
      Server.stub(:find => [])
      Database.stub(:get => nil)
      @environment = double('Environment', :servers => @servers)
      Environment.stub(:get => @environment)
    end

    context "no servers exist for the nominated environment" do
      it "should not raise an error" do
        environment = double('Environment', :servers => [])
        Environment.stub(:get).and_return(environment)
        lambda { DeployController.new.create(type, environment_name, { 'tag' => tag, 'rails_env' => rails_env }) }.should raise_error /instances already terminated/
      end
    end

    it "should create an instance of Deploy and deploy" do
      deploy_run = double('Deploy::Run')
      Deploy::Run.should_receive(:new).with(type, @environment, opts).and_return(deploy_run)
      deploy_run.should_receive(:deploy)
      DeployController.new.create(type, environment_name, opts)
    end

  end
end