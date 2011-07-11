# require 'opensrs'

class Cloud

  attr_reader :region, :account_name, :profile_name

  class << self

    def connect region, account_name, profile_name = nil
      @connection = new(region, account_name, profile_name)
      Inform.info("Connected to AWS in %{region} using account %{account_name}", :region => region, :account_name => account_name)
    end

    def method_missing method, *args
      @connection.send(method, *args)
    end

  end

  def account
    @account ||= Account.read(account_name)
  end

  def compute
    @compute ||= Fog::Compute.new(fog_credentials.merge({:provider => 'AWS'}))
  end

  def security_groups
    @security_groups ||= compute.security_groups.inject({}) { |h, g| h[g.name] = g; h }
  end

  def valid_servers
    @valid_servers ||= Cloud.compute.servers.select{ |s| %w{running pending}.include?(s.state) }
  end

  def keypair_exists? keypair
    !!compute.key_pairs.get(keypair)
  end

  def elb
    @elb ||= Fog::AWS::ELB.new(fog_credentials)
  end

  def rds
    @rds ||= Fog::AWS::RDS.new(fog_credentials)
  end

  def rds_authorized_ec2_owner_ids
    # XXX - Does this belong in Fog::AWS::RDS ?
    @rds_authorized_ec2_owner_ids ||= rds.security_groups.detect { |security_group|
      security_group.id == 'default'
    }.ec2_security_groups.select { |ec2_security_group|
      ec2_security_group["EC2SecurityGroupName"] == "default" && ec2_security_group["Status"] == "authorized"
    }.collect { |h|
      h["EC2SecurityGroupOwnerId"]
    }
  end

  def profile
    if profile_name
      @profile ||= Profile.read(profile_name)
    end
  end

  def keyfile_path(key_name)
    account_dir = File.join(ENV['HOME'], '.dew','accounts')
    File.join(account_dir, 'keys', account_name, region, "#{key_name}.pem")
  end
  
  def has_dns?
    account.has_dns?
  end
  
  def dns
    # @dns ||= OpenSRS::Server.new(account.opensrs_credentials)
  end

  private

  def initialize region, account_name, profile_name = nil
    @region = region
    @account_name = account_name
    @profile_name = profile_name      
  end

  def fog_credentials
    {:region => region, :aws_access_key_id => account.aws_access_key_id, :aws_secret_access_key => account.aws_secret_access_key}
  end
end
