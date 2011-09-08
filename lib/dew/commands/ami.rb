require 'dew/controllers/amis_controller'

class AMIsCommand < Clamp::Command

  def puppet_node_filename node_name
    File.join(ENV['HOME'], '.dew', 'puppet', 'manifests', 'nodes', "#{node_name}.pp")
  end

  def controller
    @controller ||= AMIsController.new
  end

  default_subcommand "index", "Show AMIs" do

    def execute
      controller.index
    end

  end

  subcommand "show", "Show an AMI" do

    parameter "AMI_NAME", "Name of AMI"

    def execute
      controller.show(ami_name)
    end

  end

  subcommand "create", "Create a new AMI" do

    parameter "PUPPET_NODE_NAME", "Puppet node (in puppet/manifests/nodes/*.pp) to run on AMI" do |puppet_node_name|
      unless File.exist?(puppet_node_filename(puppet_node_name))
        raise ArgumentError, "Can't find puppet/#{puppet_node_filename(puppet_node_name)}: check that puppet submodule is checked out and node exists"
      end
      puppet_node_name
    end
    
    parameter "AMI_NAME", "What to call the newly created AMI"
    option ['-p', '--prototype-profile'], "AMI_PROTOTYPE_NAME", "Profile to use as a prototype for the AMI", :default => 'ami-prototype'
    
    def execute
      controller.create(ami_name, puppet_node_name, prototype_profile)
    end

  end

  subcommand "destroy", "Destroy an existing AMI" do

    parameter "AMI_NAME", "Name of AMI to destroy"
    option ['-f', '--force'], :flag, "Don't ask for confirmation before destroying", :default => false

    def execute
      controller.destroy(ami_name, :force => force?)
    end

  end
end
