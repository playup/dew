require File.expand_path(File.join(File.dirname(__FILE__), '..', 'deploy', 'puge'))

module Deploy

  class Run

    attr_reader :deploy_type, :environment, :opts

    def initialize deploy_type, environment, opts
      @deploy_type = deploy_type
      @environment = environment
      @opts = opts
    end

    def deploy
      Deploy.const_get(deploy_type.capitalize).new(@environment.servers, @opts).deploy
    end
  end
end