require 'yaml'

class Profile

  attr_reader :profile_name
  attr_accessor :ami, :size, :security_groups, :keypair, :count
  attr_accessor :rds_size, :rds_storage_size, :elb_listener_ports, :username
  attr_reader :instance_disk_size
  
  AWS_RESOURCES = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'aws_resources.yaml'))

  DEFAULT_RDS_STORAGE_SIZE = 5
  DEFAULT_USERNAME = 'ubuntu'
  
  def self.read(profile_name)
    new(
      profile_name,
      YAML.load_file(profile_path(profile_name))
    )
  end
  
  def self.profile_path(profile_name)
    File.join(ENV['HOME'], '.dew', 'profiles', "#{profile_name}.yaml")
  end

  def has_elb?
    elb_listener_ports != nil
  end

  def has_rds?
    rds_size != nil
  end

  def initialize(profile_name, init_yaml = nil)
    @profile_name = profile_name
    populate_from_yaml(Cloud.region, init_yaml) if init_yaml
  end
  
  def populate_from_yaml(region, yaml)
    @username = DEFAULT_USERNAME    # do we actually need this?  There are no instances...
  
    if yaml['instances']
      @ami = yaml['instances'].fetch('amis', {})[region]
      @size = yaml['instances']['size']
      @security_groups = yaml['instances'].fetch('security-groups', 'default') #TODO is this fallback tested?
      @keypair = yaml['instances']['keypair']
      @count = yaml['instances']['count'].to_i
      @username = yaml['instances'].fetch('username', DEFAULT_USERNAME) #TODO is this fallback tested?
      @instance_disk_size = yaml['instances'].fetch('disk-size', nil)
    end
    
    if yaml['elb']
      @elb_listener_ports = yaml['elb']['listener_ports']
    end
    
    if yaml['rds']
      @rds_size = yaml['rds']['size']
      @rds_storage_size = yaml['rds'].fetch('storage', DEFAULT_RDS_STORAGE_SIZE)
    end  
  end
  
  TO_STRING_TEMPLATE = "%{memory} GB memory, %{processor} ECUs processor, %{storage} GB storage, %{platform}-bit platform"

  def self.size_to_s(size)
    flavor = Cloud.compute.flavors.detect { |f| f.id == size }
    instance_hash = { :memory => flavor.ram.to_s, :processor => flavor.cores.to_s, :storage => flavor.disk.to_s, :platform => flavor.bits.to_s }
    instance_hash.inject(TO_STRING_TEMPLATE) { |res,(k,v)| res.gsub(/%\{#{k}\}/, v) }
  end

  def to_s
    db_instance_str = "%{memory} memory, %{processor} processor, %{platform} platform, %{io_performance} I/O performance"
    table { |t|
      t << [ "#{count} instance#{'s' if count > 1}", "#{size.inspect} (#{self.class.size_to_s(size)})"]
      t << ['disk image', ami.inspect]
      t << ['load balancer', "listener ports: #{elb_listener_ports.inspect}"] if has_elb?
      t << ['database', "#{rds_size.inspect} (#{rds_storage_size}Gb) (#{AWS_RESOURCES['db_instance_types'][rds_size].inject(db_instance_str) { |res,(k,v)| res.gsub(/%\{#{k}\}/, v) } })"] if has_rds?
      t << ['security groups', security_groups.inspect]
      t << ['keypair', keypair.inspect]
    }.to_s
  end
  
  def instance_disk_size?
    !!@instance_disk_size
  end
end
