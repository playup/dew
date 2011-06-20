class DeployController
  
  def create deploy_type, environment_name, opts
    if Environment.get(environment_name).servers.empty?
      raise "Environment #{environment_name.inspect} doesn't exist or appears to have all instances already terminated"
    end

    Deploy::Run.new(deploy_type, Environment.get(environment_name), opts).deploy
  end
end