require 'yaml'

class Account

  def self.read(account_name)
    Account.new YAML.load File.read File.join [ ENV['HOME'], '.dew', 'accounts', "#{account_name}.yaml" ]
  end

  def self.user_ids
    Dir[File.join(ENV['HOME'], '.dew', 'accounts', '*.yaml')].map do |filename|
      Account.read(File.basename(filename).gsub(/.yaml$/, '')).aws_user_id
    end
  end

  def aws_access_key_id
    @yaml['aws']['access_key_id']
  end

  def aws_secret_access_key
    @yaml['aws']['secret_access_key']
  end

  def aws_user_id
    @yaml['aws']['user_id'].gsub('-', '')
  end

  def initialize(yaml)
    @yaml = yaml
  end
end
