require 'dew/models/profile'

require 'readline'
class EnvironmentsController

  def select_option(prompt, opt_hash, new=false)
    result = false
    while not result
      selection = nil
      say "<%= color('#{prompt}:', YELLOW, BOLD) %>"
      choose do |menu|
        menu.readline = true
        #menu.layout = :one_line
        #menu.shell = true
        opt_hash.each { |k, v| menu.choice(k) { selection = k  } }
        menu.hidden('new', "Select this to create a new one") { result = 0 } if new
      end
      if selection
        say "<%= color('#{opt_hash[selection]}', GREEN, BOLD) %>"
        result = selection if agree "<%= color('Use #{selection.inspect}?', YELLOW, BOLD) %> "
      end
    end
    result
  end

  def create_new_profile(account_name)
    profile_name = select_option 'Select a profile ("new" to create a new one)', Profile.all.inject({}) { |h, profile_name| h[profile_name] = Profile.read(profile_name) ; h }, new = true
    if profile_name == 0
      count = select_option 'Select the number of instances', (1..5).inject({}) { |h, count| h[count.to_s] = "Create #{count} instances"; h }
      size = select_option 'Select an instance size', Profile::AWS_RESOURCES['instance_types'].keys.inject({}) { |h, size| h[size] = Profile.size_to_s(size); h }
      region = select_option 'Select a region', Profile::AWS_RESOURCES['regions'].keys.inject({}) { |h, region| h[region] = Profile::AWS_RESOURCES['regions'][region] ; h }

      #ami_keys = %w(name id state architecture kernel_id description)
      ami_keys = %w(id architecture block_device_mapping description location owner_id state type is_public kernel_id platform product_codes ramdisk_id root_device_type root_device_name tags name)
      ami = select_option 'Select a disk image', AMIsController.new.my_amis.inject({}) { |h, ami|
        ami_hash = ami_keys.inject({}) { |h2, k|
          h2[k] = ami.send(k); h2
        }
        h[ami.id] = table(nil, *ami_hash.to_a).to_s
        h
      }

      keypairs = Dir[Pathname.new(ENV['HOME']) + '.dew' + 'accounts' + 'keys' + account_name + region + '*.pem'].inject({}) { |h, f| h[Pathname(f).basename('.pem').to_s] = f; h }
      keypair = select_option 'Select a keypair', keypairs
      security_group = select_option 'Select a security group', ['default'].inject({}) { |h, g| h[g] = g ; h }

      profile_name = ask("<%= color('Save this profile as:', YELLOW, BOLD) %> ")
      Profile.write(profile_name, count, size, region, ami, keypair, security_group)
    end
    profile_name
  end

  def create(name, profile_name, opts={})
    profile = Profile.read(profile_name)
    if opts[:force] || (
      Inform.info("About to create environment %{name} using the following %{profile_name} profile:\n%{profile}" , :name => name, :profile_name => profile.profile_name, :profile => profile.to_s)
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
