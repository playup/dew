class Database < FogModel

  def self.create! name, size, password
    new Cloud.rds.servers.create(
              :engine => 'MySQL',
              :master_username => 'root',
              :password => password,
              :id => name,
              :allocated_storage => '5',
              :flavor_id => size
    )
  end

  def self.get name
    db = Cloud.rds.servers.get(name)
    new db if db
  end
  
  def public_address
    fog_object.endpoint['Address']
  end
  
  def db_environment_file password
    <<-EOF
DB_HOST=#{fog_object.endpoint['Address']}
DB_NAME=#{id}
DB_USERNAME=#{master_username}
DB_PASSWORD=#{password}
    EOF
  end
  
end
