require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe Deploy::Run do

  let (:deploy_type) { 'puge' }
  let (:tag) { 'puge-1.16.1' }
  let (:rails_env) { 'development' }
  let (:servers) { (0..1).map { |i| double("Server #{i}").as_null_object} }
  let (:database) { double('Database')}
  let (:environment) {double('Environment', :servers => servers, :database => database)}
  let (:opts) { { 'tag' => tag, 'rails_env' => rails_env } }

  before :each do
    @deploy_run = Deploy::Run.new(deploy_type, environment, opts)
    Cloud.stub(:region => 'ap-southeast-1', :account_name => 'myaccount', :profile_name => 'development')
  end

  it { @deploy_run.deploy_type.should == deploy_type }
  it { @deploy_run.environment.should == environment }
  it { @deploy_run.opts['tag'].should == tag }
  it { @deploy_run.opts['rails_env'].should == rails_env }

  describe :deploy do
    before :each do
      Deploy::Puge.stub(:run => nil)
    end

    it "should perform a deploy run for each associated server" do
      deloy_puge_class_name = 'Deploy::Puge'
      deploy_puge = double(deloy_puge_class_name)

      Deploy.should_receive(:const_get).with(deploy_type.capitalize).and_return(deloy_puge_class_name)
      deloy_puge_class_name.should_receive(:new).with(servers, opts).and_return(deploy_puge)
      deploy_puge.should_receive(:deploy)
      @deploy_run.deploy
    end
  end
end