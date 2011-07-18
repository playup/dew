require 'dew/controllers/environments_controller'


class EnvironmentsCommand < Clamp::Command

  #STATUS_KEYS=%w(arch cpu_count cpu_freq disk ec2_cost ip_address load_average mem_available mem_used network processes reboot_required release time_utc updates_available uptime users)
  STATUS_KEYS=%w(ip_address arch cpu_count cpu_freq disk ec2_cost load_average mem_available mem_used network processes release time_utc uptime)
  STATUS_CMD="'[ -d ~/.byobu ] || mkdir ~/.byobu; touch ~/.byobu/status; for cmd in #{STATUS_KEYS.join(' ')}; do echo `/usr/lib/byobu/$cmd 2>/dev/null`; done'"

  def controller
    @controller ||= EnvironmentsController.new
  end

  default_subcommand "index", "Show environments" do

    def execute
      controller.index
    end

  end

  subcommand "create", "Create a new environment" do

    option ['-f', '--force'], :flag, "Don't ask for confirmation before creating", :default => false
    parameter "PROFILE", "Profile describing resources to be created", :attribute_name => 'profile_name'
    parameter "ENVIRONMENT_NAME", "Name of the environment"

    def execute
      controller.create(environment_name, profile_name, :force => force?)
    end

  end

  subcommand "show", "Show environment" do

    parameter "ENVIRONMENT_NAME", "Name of the environment"

    def execute
      controller.show(environment_name)
    end

  end

  subcommand "status", "Get the status of an instance (NB. requires byobu to be installed)" do
    parameter "[ENVIRONMENT_NAME]", "Name of the environment"
    option ['-i', '--instance'], 'INSTANCE_NUMBER', "Which instance to SSH to", :default => 1 do |s|
      Integer(s)
    end

    def execute
      environment_owners = Environment.owners
      environment_owners = [environment_owners.detect { |o| o[:name] == environment_name }] if environment_name
      rows = []
      environment_owners.collect { |o|
        environment_name = o[:name]
        environment_owner = o[:owner]
        instance_count = Environment.get(environment_name).servers.size
        (1..instance_count).collect { |instance_no|
          server = get_server(environment_name, instance_no)
          if server.credentials
            command = "ssh #{server.credentials} #{STATUS_CMD}"
            Inform.debug("Running %{command}", :command => command)
            rows << [environment_name, environment_owner]+`#{command}`.split("\n")
          end
        }
      }
      Inform.info "\n#{rows.empty? ? "None" : table(%w(env owner)+STATUS_KEYS, *rows)}"
    end
  end

  subcommand "ssh", "SSH to an environment" do
    parameter "ENVIRONMENT_NAME", "Name of the environment"
    option ['-i', '--instance'], 'INSTANCE_NUMBER', "Which instance to SSH to", :default => 1 do |s|
      Integer(s)
    end
    option ['-p', '--print'], :flag, "Print the SSH credentials instead of actually performing the SSH operation", :default => false

    def execute
      server = get_server(environment_name, instance)
      if server.credentials
        if print?
          puts server.credentials
        else
          command = "ssh #{server.credentials}"
          Inform.debug("Running %{command}", :command => command)
          system command
        end
      end
    end
  end
  
  subcommand "run", "Run a script or command on each instance in the environment" do
    parameter "ENVIRONMENT_NAME", "Name of the environment"
    option ['-s', '--script'], "FILENAME", "Script to run on each instance"
    option ['-a', '--args'], "ARGUMENTS", "Optional arguments to the script provided in --script", :default => ''
    option ['-c', '--command'], "COMMAND", "Command to run on each instance"
    
    def execute
      raise "Please supply either -s or -c" unless script or command
      raise "--args only compatiable with --script" if command and args
      
      env = Environment.get(environment_name)
      
      Inform.info("Running on %{l} servers", :l => env.servers.length) do
        env.servers.each do |server|
          start = Time.now
          ssh = server.ssh
          if script
            ssh.upload(script, '/tmp/script')
            ssh.run("chmod +x /tmp/script")
            ssh.run("/tmp/script #{args}", :quiet => false)
            ssh.run("rm /tmp/script")
          else
            ssh.run(command, :quiet => false)
          end
          Inform.debug("%{s} took %{time} seconds", :s => server.id, :time => (Time.now - start))
        end
      end
    end
  end

  subcommand "destroy", "Destroy an existing environment" do

    option ['-f', '--force'], :flag, "Don't ask for confirmation before destroying", :default => false
    parameter "ENVIRONMENT_NAME", "Name of the environment to be destroyed"

    def execute
      controller.destroy(environment_name, :force => force?)
    end

  end

  def get_server(environment_name, instance_no)
    env = Environment.get(environment_name)
    server = env.servers[instance_no - 1]
    raise "Environment only has #{env.servers.length} instances, can't SSH to instance ##{instance}" unless server
    server
  end

end
