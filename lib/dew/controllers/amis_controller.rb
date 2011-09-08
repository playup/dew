require 'dew/controllers/environments_controller'

class AMIsController

  def create(ami_name, puppet_node_name, prototype_profile_name)
    Inform.info("Creating new AMI %{ami_name} using puppet node %{puppet}", :ami_name => ami_name, :puppet => puppet_node_name)
    environment_name = ami_name + '-prototype-' + $$.to_s

    environment = Environment.create(environment_name, Profile.read(prototype_profile_name))
    @prototype = environment.servers.first
    Inform.debug("Using server %{id} at %{ip} as our prototype.", :id => @prototype.id, :ip => @prototype.public_ip_address)

    Inform.debug("Installing puppet...")
    install_puppet_on_prototype
    Inform.debug("Copying puppet configuration... ")
    copy_puppet_to_prototype
    Inform.debug("Running puppet node %{node}... ", :node => puppet_node_name)
    run_puppet_node_on_prototype puppet_node_name

    ami_id = Inform.info "Creating new ami with name %{ami_name}", :ami_name => ami_name do
      @prototype.create_ami ami_name
    end
    Inform.info("New AMI id is %{ami_id}", :ami_id => ami_id)
    environment.destroy
  end

  def index
    # Inform.info("AMIs:\n#{Cloud.compute.images.all('owner_id' => Cloud.account.aws_user_id)}")
    # /home/chris/.rvm/gems/ruby-1.9.2-p180@AWS/gems/excon-0.6.3/lib/excon/connection.rb:179:in `request': InvalidParameterValue => The filter 'owner_id' is invalid (Fog::Service::Error)
    my_amis = Cloud.compute.images.all.select { |x| x.owner_id == Cloud.account.aws_user_id }
    keys = %w(name id state architecture kernel_id description)
    Inform.info(View.new('My AMIs', my_amis, keys).index)
  end

  def show ami_name
    my_amis = Cloud.compute.images.all('name' => ami_name)
    raise "AMI named #{ami_name} not found!" if my_amis.empty?
    keys = %w(id architecture block_device_mapping description location owner_id state type is_public kernel_id platform product_codes ramdisk_id root_device_type root_device_name tags name)
    Inform.info(View.new('My AMIs', my_amis, keys).show(0))
  end

  def destroy ami_name, opts={}
    ami = Cloud.compute.images.all('name' => ami_name).first
    raise "AMI named #{ami_name} not found!" unless ami
    if opts[:force] || agree("<%= color('Are you sure?', YELLOW, BOLD) %> ")
      Inform.info("Destroying AMI named %{n}", :n => ami_name) do
        ami.deregister
      end
    else
      Inform.info "Aborting AMI destruction"
    end
  end

  private

  def ssh
    @ssh ||= @prototype.ssh
  end

  def install_puppet_on_prototype
    Inform.info("Installing puppet") do
      ssh.run('sudo apt-get update', :quiet_stderr => true)
      ssh.run('sudo apt-get -q -y install puppet', :quiet_stderr => true) # chatty
    end
  end

  def copy_puppet_to_prototype
    Inform.info("Uploading puppet configuration") do
      ssh.upload(File.join(ENV['HOME'], '.dew', 'puppet'), '/tmp/puppet')
      ssh.run("sudo rm -rf /etc/puppet")
      ssh.run("sudo mv /tmp/puppet /etc/puppet")
    end
  end

  def run_puppet_node_on_prototype puppet_node_name
    Inform.info("Running puppet node %{name} (this may take a while)", :name => puppet_node_name) do
      ssh.run("sudo puppet /etc/puppet/manifests/nodes/#{puppet_node_name}.pp #{puppet_node_name} > /tmp/puppet_run_log 2>&1")
    end
  end
end
