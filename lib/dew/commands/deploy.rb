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
    option ['--server-name'], 'SERVER_NAME', "Server name for Name-Based Virtual Host"
    option ['--ssl-certificate'], 'FILE', "SSL Certificate file"
    option ['--ssl-private-key'], 'FILE', "SSL Private Key file"
    option ['--[no-]passenger'], :flag, "Use passenger (just server public/* if unset)", :default => true, :attribute_name => :use_passenger
    option ['--gamej-proxy'], 'GAMEJ_PROXY', "GameJ Reverse Proxy"
    option ['--create-database'], :flag, "Create the database, even if this isn't the initial checkout", :default => false

    def check_and_remove_rvmrc
      if ssh.exist? "#{application_name}/.rvmrc"
        Inform.debug(".rvmrc discovered - removing to avoid Passenger conflicts")
        # XXX We need a company-wide standard or a better way of supporting .rvmrc stuffs
        ssh.run "rm -f #{application_name}/.rvmrc"
      end
    end

    def use_ssl?
      ssl_certificate || ssl_private_key
    end
    
    def execute
      if use_ssl?
        raise "--server-name required if SSL credentials supplied" unless server_name
        raise "--ssl-private-key required if SSL certificate supplied" unless ssl_private_key
        raise "--ssl-private-key file #{ssl_private_key} does not exist" unless File.exist?(ssl_private_key)
        raise "--ssl-certificate required if SSL private key supplied" unless ssl_certificate
        raise "--ssl-certificate file #{ssl_certificate} does not exist" unless File.exist?(ssl_certificate)
      end

      env = Environment.get(environment_name)
      raise "Unknown environment #{environment_name}" unless env

      db_managed = false

      env.servers.each do |server|
        Inform.info("Working with server %{id} of %{l} servers", :id => server.id, :l => env.servers.length)
        env.remove_server_from_elb(server) if env.has_elb?

        @ssh = server.ssh
        is_redhat = ssh.exist?('/etc/redhat-release')
        if is_redhat
          Inform.info("RedHat server detected")
        end
        initial = !ssh.exist?(application_name)

        Inform.info("%{app} doesn't exist - initial install", :app => application_name) if initial

        Inform.info("Stopping apache") do
          if is_redhat
            ssh.run "sudo /etc/init.d/httpd stop"
          else
            ssh.run "sudo apache2ctl stop"
          end
        end

        Inform.info("Obtaining version %{v} of %{app}", :v => revision, :app => application_name) do
          if initial
            unless ssh.exist?('.ssh/known_hosts') && ssh.read('.ssh/known_hosts').include?(File.read(template('known_hosts')))
              Inform.debug("Writing out ~/.ssh/known_hosts file to allow github clone")
              ssh.upload template('known_hosts'), ".ssh/known_hosts"
            end
            Inform.debug("Cloning %{app} in to ~/%{app}", :app => application_name)
            ssh.run "git clone git@github.com:playup/#{application_name}.git #{application_name}"
          else
            Inform.debug("Updating %{app} repository",  :app => application_name)
            check_and_remove_rvmrc unless is_redhat
            ssh.run "cd #{application_name}; git fetch -q"
          end

          check_and_remove_rvmrc unless is_redhat
          Inform.debug("Checking out version %{version}", :version => revision)
          ssh.run "cd #{application_name} && git checkout -q -f #{revision}"
          check_and_remove_rvmrc unless is_redhat
        end

        cd_and_rvm = "cd #{application_name} && . /usr/local/rvm/scripts/rvm && rvm use ruby-1.9.2-p180 && RAILS_ENV=#{rails_env} "
        if is_redhat
          cd_and_rvm = "cd #{application_name} && RAILS_ENV=#{rails_env} "
        end

        Inform.info("Updating/installing gems") do
          ssh.run cd_and_rvm + "bundle install --without development test"
        end

        if ssh.exist?("#{application_name}/config/database.dew.yml")
          Inform.info("config/database.dew.yml found, linking to database.yml") do
            ssh.run cd_and_rvm + "ln -sf database.dew.yml config/database.yml"
          end
        end

        if ssh.exist?("#{application_name}/config/database.yml")
          if !db_managed
            Inform.info("config/database.yml exists, creating and/or updating database") do
              if initial || create_database?
                Inform.debug("Creating database")
                ssh.run cd_and_rvm + "bundle exec rake db:create"
              end
              Inform.debug("Updating database")
              ssh.run cd_and_rvm + "bundle exec rake db:migrate"
              db_managed = true # don't do database steps more than once
            end
          end
        else
          Inform.info("No config/database.yml, skipping database step")
        end
        
        build_script = 'script/build'
        if ssh.exist? application_name + '/' + build_script
          Inform.info("Build script discovered at %{build_script}, running", :build_script => build_script) do
            ssh.run cd_and_rvm + "bundle exec #{build_script}"
          end
        end
          
        
        if use_ssl?
          if is_redhat
            raise "SSL not yet supported for redhat"
          end
          Inform.info "Enabling Mod SSL" do
            ssh.run "sudo a2enmod ssl"
          end
          Inform.info "Uploading SSL Certificate & Private Key" do
            ssh.run "sudo mkdir -p /etc/apache2/certs" unless ssh.exist?("/etc/apache2/certs")
            ssh.upload ssl_certificate, "/tmp/sslcert"
            ssh.run "sudo mv -f /tmp/sslcert /etc/apache2/certs/#{application_name}.crt"
            ssh.upload ssl_private_key, "/tmp/sslkey"
            ssh.run "sudo mv -f /tmp/sslkey /etc/apache2/certs/#{application_name}.key"
          end
        end

        if gamej_proxy
          if is_redhat
            raise "gamej proxy not yet supported for redhat"
          end
          Inform.info "Enabling Mod Proxy" do
            ssh.run "sudo a2enmod proxy"
            ssh.run "sudo a2enmod proxy_http"
          end
        end
        
        Inform.info("Starting application") do
          conf_dest = is_redhat ? "/etc/httpd/conf.d/#{application_name}.conf" : "/etc/apache2/sites-available/#{application_name}"
          if ssh.exist?('/etc/apache2/sites-enabled/000-default')
            Inform.debug("Disabling default apache site")
            ssh.run "sudo a2dissite default"
          end
          Inform.debug("Uploading passenger config")
          working_directory = ssh.run("cd #{application_name} && pwd").chomp
          passenger_config = ERB.new(File.read template('apache.conf.erb')).result(OpenStruct.new(
            :use_passenger? => use_passenger?,
            :use_ssl? => use_ssl?,
            :server_name => server_name,
            :rails_env => rails_env,
            :log_dir => is_redhat ? '/var/log/httpd' : '/var/log/apache2',
            :application_name => application_name,
            :working_directory => working_directory,
            :gamej_proxy => gamej_proxy
          ).instance_eval {binding})
          apache_tmpfile = ssh.run("mktemp -t apacheconf").chomp
          ssh.write passenger_config, apache_tmpfile
          ssh.run "sudo cp #{apache_tmpfile} #{conf_dest}"
          ssh.run "rm #{apache_tmpfile}"
          ssh.run "sudo chmod 0644 #{conf_dest}" # yeah, I don't know why it gets written as 0600
          unless is_redhat || ssh.exist?('/etc/apache2/sites-enabled/#{application_name}')
            Inform.debug("Enabling site in apache")
            ssh.run "sudo a2ensite #{application_name}"
          end
          Inform.debug("Restarting apache")
          if is_redhat
            ssh.run "sudo /etc/init.d/httpd start"
          else
            ssh.run "sudo apache2ctl start"
          end
        end

        unless server_name || !use_passenger?
          status_url = "http://#{server.public_ip_address}/status"
          Inform.info("Checking status URL at %{u}", :u => status_url) do
            response = JSON.parse(open(status_url).read)
            unless response.include?('status') && response['status'] == 'OK'
              raise "Did not receive an OK status response."
            end
          end
        else
          Inform.warning "Skipping health check as we don't yet support forcing server_name on HTTP"
        end
        env.add_server_to_elb(server) if env.has_elb?
      end
    end
    
    private
    
    def ssh
      @ssh
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
