require 'dew/controllers/amis_controller'
require 'erb' # XXX
require 'ostruct' # XXX
require 'open-uri' # XXX
require 'json' # XXX

class DeployCommand < Clamp::Command

  def template filename
    File.join(File.dirname(__FILE__), 'deploy', 'templates', filename)
  end

  subcommand 'passenger', "Deploy a Passenger-compatiable application to an environment" do
    parameter "APPLICATION_NAME", "Repository and application name"
    parameter "REVISION", "Git revision to deploy (tag, branch, or commit id)"
    parameter "ENVIRONMENT_NAME", "Environment to deploy into"

    option ['--rails-env'], 'ENVIRONMENT', "Rails environment to use", :default => 'production'

    def execute
      env = Environment.get(environment_name)
      env.servers.each do |server|
        Inform.info("Working with server %{id} of %{l} servers", :id => server.id, :l => env.servers.length)
        env.remove_server_from_elb(server) if env.has_elb?

        ssh = server.ssh
        initial = !ssh.exist?(application_name)

        Inform.info("%{app} doesn't exist - initial install", :app => application_name) if initial

        Inform.info("Stopping apache") do
          ssh.run "sudo apache2ctl stop"
        end

        Inform.info("Obtaining version %{v} of %{app}", :v => revision, :app => application_name) do
          if initial
            Inform.debug("Writing out ~/.ssh/known_hosts file to allow github clone")
            ssh.upload template('known_hosts'), ".ssh/known_hosts"
            Inform.debug("Cloning %{app} in to ~/%{app}", :app => application_name)
            ssh.run "git clone git@github.com:playup/#{application_name}.git #{application_name}"
          else
            Inform.debug("Updating %{app} repository",  :app => application_name)
            ssh.run "cd #{application_name}; git fetch -q"
          end

          Inform.debug("Checking out version %{version}", :version => revision)
          ssh.run "cd #{application_name} && git checkout -q -f origin/#{revision}"
        end

        cd_and_rvm = "cd #{application_name} && . /usr/local/rvm/scripts/rvm && rvm use ruby-1.9.2 && RAILS_ENV=#{rails_env} "

        Inform.info("Updating/installing gems") do
          ssh.run cd_and_rvm + "bundle install"
        end

        if ssh.exist?("#{application_name}/config/database.yml")
          Inform.info("config/database.yml exists, creating and/or updating database") do
            Inform.debug("Creating database") if initial
            ssh.run cd_and_rvm + "rake db:create" if initial
            Inform.debug("Updating database")
            ssh.run cd_and_rvm + "rake db:migrate"
          end
        else
          Inform.info("No config/database.yml, skipping database step")
        end

        Inform.info("Starting application with passenger") do
          if ssh.exist?('/etc/apache2/sites-enabled/000-default')
            Inform.debug("Disabling default apache site")
            ssh.run "sudo a2dissite default"
          end
          Inform.debug("Uploading passenger config")
          passenger_config = ERB.new(File.read template('apache.conf.erb')).result(OpenStruct.new(
            :rails_env => rails_env,
            :application_name => application_name,
            :working_directory => "/home/ubuntu/#{application_name}"
          ).instance_eval {binding})
          ssh.write passenger_config, "/tmp/apache.conf"
          ssh.run "sudo cp /tmp/apache.conf /etc/apache2/sites-available/#{application_name}"
          ssh.run "sudo chmod 0644 /etc/apache2/sites-available/#{application_name}" # yeah, I don't know why it gets written as 0600
          unless ssh.exist?('/etc/apache2/sites-enabled/#{application_name}')
            Inform.debug("Enabling passenger site in apache")
            ssh.run "sudo a2ensite #{application_name}"
          end
          Inform.debug("Restarting apache")
          ssh.run "sudo apache2ctl restart"
        end

        status_url = "http://#{server.public_ip_address}/status"
        Inform.info("Checking status URL at %{u}", :u => status_url) do
          response = JSON.parse(open(status_url).read)
          unless response.include?('status') && response['status'] == 'OK'
            raise "Did not receive an OK status response."
          end
        end
        env.add_server_to_elb(server) if env.has_elb?
      end
    end

  end

  subcommand 'puge', "Deploy PUGE" do
    parameter "TAG", "Git revision to deploy (tag, branch, or commit id)"
    parameter "ENVIRONMENT_NAME", "Environment to deploy into"
    parameter "RAILS_ENV", "Rails environment used for db setup"

    def execute
      Inform.info("Deploying PUGE tag %{tag} using RAILS_ENV %{rails_env} to environment %{environment_name}", :tag => tag, :rails_env => rails_env, :environment_name => environment_name)

      DeployController.new.create('puge', environment_name, { 'tag' => tag, 'rails_env' => rails_env })
      Inform.info("Deployed successfully.")
    end
  end
end
