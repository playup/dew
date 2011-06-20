require 'yaml'
require 'pathname'

class Profile

  attr_reader :profile_name
  attr_accessor :ami, :size, :security_groups, :keypair, :count
  attr_accessor :rds_size, :elb_listener_ports

  AWS_RESOURCES = YAML.load(File.read(File.join(File.dirname(__FILE__), '..', 'aws_resources.yaml')))

  DIR = Pathname.new(ENV['HOME']) + '.dew' + 'profiles'

  def self.all
    @all ||= Dir[DIR+'*.yaml'].collect { |f| Pathname(f).basename('.yaml').to_s }.sort.select { |name| name != 'template' }
  end

  def self.read(profile_name)
    file = File.read(DIR + "#{profile_name}.yaml")
    yaml = YAML.load(file)
    profile = new(profile_name)
    if yaml['instances']
      profile.ami = yaml['instances']['amis'][Cloud.region]
      profile.size = yaml['instances']['size']
      profile.security_groups = yaml['instances']['security-groups'] || ['default']
      profile.keypair = yaml['instances']['keypair']
      profile.count = yaml['instances']['count'].to_i
    end
    if yaml['elb']
      profile.elb_listener_ports = yaml['elb']['listener_ports']
    end
    if yaml['rds']
      profile.rds_size = yaml['rds']['size']
    end
    profile
  end

  def self.write(profile_name, count, size, region, ami, keypair, security_group)
    yaml = { 'instances' => { 'amis' => {} } }
    yaml['instances']['amis'][region] = ami
    yaml['instances']['size'] = size
    yaml['instances']['count'] = count
    yaml['instances']['security-group'] = security_group
    yaml['instances']['keypair'] = keypair

    file = File.open(DIR + "#{profile_name}.yaml", 'w')
    file.write(yaml.to_yaml)
    file.close
  end

  def has_elb?
    elb_listener_ports != nil
  end

  def has_rds?
    rds_size != nil
  end

  def initialize(profile_name)
    @profile_name = profile_name
    # :ami, :size, :security_groups, :keypair, :count
    # :rds_size, :elb_listener_ports
  end

  def self.size_to_s(size)
    #instance_str = "%{memory} memory, %{processor} processor, %{storage} storage, %{platform} platform, %{io_performance} I/O performance"
    instance_str = "%{memory} GB memory, %{processor} ECUs processor, %{storage} GB storage, %{platform}-bit platform, %{io_performance} I/O performance"
    flavor = Cloud.compute.flavors.detect { |f| f.id == size }
    instance_hash = { :memory => flavor.ram.to_s, :processor => flavor.cores.to_s, :storage => flavor.disk.to_s, :platform => flavor.bits.to_s, :io_performance => '??' }
    instance_hash.inject(instance_str) { |res,(k,v)| res.gsub(/%\{#{k}\}/, v) }
  end

  def to_s
    db_instance_str = "%{memory} memory, %{processor} processor, %{platform} platform, %{io_performance} I/O performance"
    table { |t|
      t << ['region', Cloud.region]
      t << [ "#{count} instance#{'s' if count > 1}", "#{size.inspect} (#{self.class.size_to_s(size)})"]
      t << ['disk image', ami.inspect]
      t << ['load balancer', "listener ports: #{elb_listener_ports.inspect}"] if has_elb?
      t << ['database', "#{rds_size.inspect} (#{AWS_RESOURCES['db_instance_types'][rds_size].inject(db_instance_str) { |res,(k,v)| res.gsub(/%\{#{k}\}/, v) } })"] if has_rds?
      t << ['security groups', security_groups.inspect]
      t << ['keypair', keypair.inspect]
    }.to_s
  end
end
