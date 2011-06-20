module Deploy

  class Puge

    def initialize servers, opts
      @servers = servers
      @opts = opts
    end

    def deploy
      execute_in_parallel_and_wait Proc.new { |server|
        Inform.info("%{server_id}: Cloning PUGE and checking out tag %{tag}", :server_id => server.id, :tag => @opts['tag'])
        upload_and_run(server, 'clone_puge.sh', @opts['tag'])

        Inform.info("%{server_id}: Running bundle install", :server_id => server.id)
        upload_and_run(server, 'bundle_install.sh')
      }

      # This task cannot run in parallel as there's only one RDS
      #
      Inform.info("%{server_id}: Setting up Rails database using %{rails_env} Rails environment", :server_id => @servers.first.id, :rails_env => @opts['rails_env'])
      upload_and_run(@servers.first, 'setup_rails_database.sh', @opts['rails_env'])

      execute_in_parallel_and_wait Proc.new { |server|
        Inform.info("%{server_id}: Generating PUGE WAR", :server_id => server.id)
        upload_and_run(server, 'generate_puge_war.sh', @opts['rails_env'])

        Inform.info("%{server_id}: Copying PUGE WAR into Tomcat directory", :server_id => server.id)
        upload_and_run(server, 'copy_puge_war_into_tomcat.sh')

        Inform.info("%{server_id}: Restarting Tomcat", :server_id => server.id)
        upload_and_run(server, 'restart_tomcat.sh')
      }
    end

    private

    def execute_in_parallel_and_wait proc
      threads = []

      @servers.each do |server|
        threads << Thread.new { proc.call(server) }
      end

      # wait for all threads to finish
      #
      threads.each do |thread|
        thread.join
      end
    end

    def upload_script server, script
      server.ssh.upload(File.join(ENV['HOME'], '.dew', 'deploy', 'puge', script), '.')
    end
    
    def upload_and_run server, script, *args
      upload_script(server, script)
      server.ssh.run(['./' + script, args.map {|a| "'#{a}'"}].flatten.join(" "))
    end
  end
end
