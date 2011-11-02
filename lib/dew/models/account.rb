require 'yaml'

class Account

  def initialize(yaml)
    @yaml = yaml
  end

  def self.read(account_name)
    Account.new(YAML.load_file(account_path(account_name)))
  end

  def self.user_ids
    Dir[account_path('*')].map do |filename|
      read(File.basename(filename, '.yaml')).aws_user_id
    end
  end

  def self.account_path(account_name)
    File.join(ENV['HOME'], '.dew', 'accounts', "#{account_name}.yaml")
  end

  def aws_access_key_id
    @yaml['aws']['access_key_id']
  end

  def aws_secret_access_key
    @yaml['aws']['secret_access_key']
  end

  def aws_user_id
    @yaml['aws']['user_id'].to_s.gsub('-', '')
  end
  
  def has_dns?
    @yaml.include?('dns')
  end

  def dns_key
    @yaml['dns']['key']
  end
  
  def dns_domain
    @yaml['dns']['domain']
  end
  
end
