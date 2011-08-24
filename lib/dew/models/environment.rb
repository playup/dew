require 'dew/validations'

class Environment
  include Validations

  attr_reader :name, :servers, :database

  def initialize name, servers=[], database=nil
    @name = name
    @servers = servers
    @database = database
    valid?
  end

  def valid?
    Validation::validates_format_of @name, /^[a-zA-Z0-9-]+$/
  end

  def self.get name
    servers = Server.find('Environment', name)
    database = Database.get(name)
    servers.length > 0 || database ? new(name, servers, database) : nil
  end

  def self.create(name, profile)
    raise "Keypair '#{profile.keypair}' is not available in AWS #{Cloud.region}." unless Cloud.keypair_exists?(profile.keypair)
    raise "AMI for '#{Cloud.region}' is not setup in the '#{profile.profile_name}' profile." unless profile.ami

    environment = new(name)
    Inform.info "Creating new environment %{name}", :name => name

    # Creating the database is the longest running task, so do that first.
    password = Password.random if profile.has_rds?
    environment.add_database(profile.rds_size, password) if profile.has_rds?

    (1..profile.count).each do
      environment.add_server(profile.ami, profile.size, profile.keypair, profile.security_groups, profile.username)
    end
  
    environment.add_elb(profile.elb_listener_ports) if profile.has_elb?
  
    environment.wait_until_ready

    environment.configure_servers_for_database password if profile.has_rds?
    Inform.info "Environment %{name} ready!", :name => name
    environment
  end

  def self.owners
    Cloud.valid_servers.collect(&:tags).collect { |h| {:name => h['Environment'], :owner => h['Creator']} if h['Environment'] }.uniq.compact
  end

  def self.index
    #environments = rows.inject({}) { |h, (name, owner)| h[name] = Environment.get(name); h }
    #items = rows.collect { |name, owner| [name, owner, environments[name].servers.size, environments[name].database] }
    #table(%w(name owner instance_count database), *rows).to_s.indent
    Inform.info View.new('Environments', owners, %w(name owner)).index
  end

  def show(options = {})
    return show_json if options[:json]
  
    result = ""

    result << "ENVIRONMENT:\n"

    result << "NAME: #{name}\n"
    result << "REGION: #{Cloud.region}\n"
    result << "ACCOUNT: #{Cloud.account.aws_user_id}\n"

    unless servers.empty?
      #keys = %w(id flavor_id public_ip_address state created_at key_name tags)
      keys = %w(id flavor_id public_ip_address state created_at groups key_name availability_zone creator)
      servers_view = View.new('SERVERS', servers, keys)
      result << servers_view.index
    end

    if elb
      elbs_view = View.new('ELB', [elb], %w(created_at dns_name instances availability_zones))
      result << elbs_view.show(0)
    end

    if database
      databases_view = View.new('DATABASE', [database], %w(flavor_id state created_at availability_zone db_security_groups))
      result << databases_view.show(0)
    end

    Inform.info result
  end
  
  def show_json
    json = servers.map do |s|
      {
        'public_dns' => s.dns_name,
        'public_ip' => s.public_ip_address
      }
    end
    
    puts JSON.pretty_generate(json)
  end

  def destroy
    servers.each do |server|
      Inform.info("Destroying server %{serverid}", :serverid => server.id) do
        server.destroy
      end
    end
    if database
      Inform.info("Destroying database") do
        database.destroy(nil)
      end
    end
    if has_elb?
      Inform.info("Destroying load balancer") do
        Cloud.elb.delete_load_balancer(name)
      end
    end
  end

  def add_server ami, size, keypair, groups, username
    Inform.info "Adding server using AMI %{ami} of size %{size}, keypair %{keypair} and security groups %{groups.join(',')}",
      :ami => ami, :size => size, :keypair => keypair, :groups => groups do
      server = Server.create!( ami, size, keypair, groups )
      server.add_tag('Environment', name)
      server.add_tag('Creator', ENV['USER'])
      server_name = "#{name} #{servers.count + 1}"
      server.add_tag('Name', server_name)
      server.add_tag('Username', username) # Needed for SSH
      Inform.debug("%{name} ID: %{id} AZ: %{az}", :name => server_name, :id =>server.id, :az => server.availability_zone)
      servers << server
    end
  end

  def add_server_to_elb server
    Inform.debug("Adding %{id} to ELB", :id => server.id)
    Cloud.elb.register_instances_with_load_balancer([server.id], name)
  end
  
  def remove_server_from_elb server
    Inform.debug("Removing %{id} from ELB", :id => server.id)
    Cloud.elb.deregister_instances_from_load_balancer([server.id], name)
  end
      
  def add_elb listener_ports=[]
    zones = servers.map {|s| s.availability_zone}.uniq
    Inform.info "Adding Load Balancer for availability zone(s) %{zones}", :zones => zones.join(', ') do
      Cloud.elb.create_load_balancer(zones, name, listeners_from_ports(listener_ports))
      Inform.debug("ELB created, adding instances...")
      Cloud.elb.register_instances_with_load_balancer(servers.map {|s| s.id}, name)
    end
  end

  def add_database size, password
    Inform.info "Adding Database %{name} of size %{size} with master password %{password}",
      :name => name, :size => size, :password => password do
      @database = Database.create!(name, size, password)
    end
  end

  def wait_until_ready
    Inform.info "Waiting for servers to become ready" do
      servers.each do |server|
        ip_permissions = server.groups.map { |group_name| Cloud.security_groups[group_name] }.compact.collect(&:ip_permissions)
        if ip_permissions.flatten.empty?
          Inform.warning "Server %{id} has no ip_permissions in its security groups %{security_group_names}", :id => server.id, :security_group_names => server.groups.inspect
        else
          Inform.debug "Trying to connect to %{id}", :id => server.id
          server.wait_until_ready
        end
      end
    end
    if database
      Inform.info "Waiting for database to become ready" do
        database.wait_until_ready if database
      end
    end
  end

  def configure_servers_for_database password
    Inform.info "Configuring servers for database" do
      servers.each do |server|
        Inform.debug "%{id}", :id => server.id
        server.configure_for_database(database, password)
      end
    end
  end

  def elb
    @elb ||= Cloud.elb.load_balancers.detect { |elb| elb.id == name }  # XXX - need to refactor
  end

  def has_elb?
    elb_descriptions.select { |elb|
      elb['LoadBalancerName'] == name
    }.length > 0
  end

  private

  def listeners_from_ports ports
    ports.map do |port|
      {
              'Protocol' => 'TCP',
              'LoadBalancerPort' => port,
              'InstancePort' => port,
      }
    end
  end

  def elb_descriptions name = nil
    Cloud.elb.describe_load_balancers(name).body['DescribeLoadBalancersResult']['LoadBalancerDescriptions']
  end
end
