require File.expand_path(File.join(File.dirname(__FILE__), '../../spec_helper'))

describe Deploy::Puge do

  let (:tag) { 'puge-1.16.1' }
  let (:rails_env) { 'development' }
  let (:gofer) { double('Gofer').as_null_object }
  let (:servers) { (0..1).map { |i| double("Server #{i}").as_null_object} }
  let (:environment) {double('Environment', :servers => servers, :database => database)}
  let (:opts) { { 'tag' => tag, 'rails_env' => rails_env } }
  let (:run_on_servers) { servers }
  let (:base_path) { [ ENV['HOME'], '.dew', 'deploy', 'puge' ]}

  shared_examples_for "script runner" do
    it "should upload the script to the EC2 instance" do
      run_on_servers.each do |server|
        server.ssh.should_receive(:upload).with(File.join(base_path, script), File.join('.'))
      end
      Deploy::Puge.new(servers, opts).deploy
    end

    it "should run the script" do
      run_on_servers.each do |server|
        server.ssh.should_receive(:run).with(['./' + script, arguments.map { |a| "'#{a}'"}].flatten.join(" "))
      end
      Deploy::Puge.new(servers, opts).deploy
    end
  end

  describe :run do

    describe "Discrete actions" do

      describe "Clone PUGE" do
        let (:script) { 'clone_puge.sh' }
        let (:arguments) { [tag] }
        it_should_behave_like "script runner"
      end

      describe "Bundle install" do
        let (:script) { 'bundle_install.sh' }
        let (:arguments) { [] }
        it_should_behave_like "script runner"
      end

      describe "Setup Rails database" do
        let (:run_on_servers) { servers.first }
        let (:script) { 'setup_rails_database.sh' }
        let (:arguments) { [rails_env] }
        it_should_behave_like "script runner"
      end

      describe "Generate PUGE WAR" do
        let (:script) { 'generate_puge_war.sh' }
        let (:arguments) { [rails_env] }
        it_should_behave_like "script runner"
      end

      describe "Copy PUGE WAR into Tomcat directory" do
        let (:script) { 'copy_puge_war_into_tomcat.sh' }
        let (:arguments) { [] }
        it_should_behave_like "script runner"
      end

      describe "Restart Tomcat" do
        let (:script) { 'restart_tomcat.sh' }
        let (:arguments) { [] }
        it_should_behave_like "script runner"
      end
    end
  end
end
