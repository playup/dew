require 'dew/models/profile'

class EnvironmentsController

  def create(name, profile_name, opts={})
    profile = Profile.read(profile_name)
    if opts[:force] || (
      Inform.info("About to create environment %{name} using the following profile:\n%{profile}" , :name => name, :profile => profile.to_s)
      agree("<%= color('Do you wish to continue?', YELLOW, BOLD) %> ")
    )
      environment = Environment.create(name, profile)
      environment.show
      environment
    else
      Inform.info "Aborting environment creation"
    end
  end

  def index
    Environment.index
  end

  def show(name)
    before_get_environment name

    @environment.show
  end

  def destroy name, opts={}
    before_get_environment name

    @environment.show
    Inform.info "Destroying environment %{name} ...", :name => name
    if opts[:force] || agree("<%= color('Are you sure?', YELLOW, BOLD) %> ")
      @environment.destroy
      Inform.info "Environment %{name} destroyed", :name => name
    else
      Inform.info "Aborting environment destruction"
    end
  end

  # a rough before filter
  def before_get_environment(name)
    @environment = Environment.get(name)
    raise "Environment named #{name} not found!" unless @environment
  end

end
