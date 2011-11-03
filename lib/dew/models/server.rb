class Server < FogModel
  TAG_CREATION_TIMEOUT = 60
  AMI_RECOGNITION_TIMEOUT = 60
  DEFAULT_SSH_CONNECTION_TIMEOUT = 180
 
  RUNNING_SERVER_STATES = %w{pending running}

  def self.create!(options)
    ami = options.fetch(:ami)
    size = options.fetch(:size)
    keypair = options.fetch(:keypair)
    groups = options.fetch(:groups)
    disk_size = options.fetch(:disk_size, nil)
    
    Inform.info "Creating server using AMI %{ami} of size %{size}, keypair %{keypair} and security groups %{groups}",
      :ami => ami, :size => size, :keypair => keypair, :groups => groups.join(',') do
  
      server_options = {
        :image_id => ami,
        :flavor_id => size,
        :key_name => keypair,
        :groups => groups      
      }
      
      if disk_size
        server_options.merge!(
          :block_device_mapping => [
            {
              'DeviceName' => '/dev/sda1',
              'Ebs.VolumeSize' => disk_size.to_s
            }
          ]        
        )
      end
  
      new(Cloud.compute.servers.create(server_options))
    end
  end

  def self.find tag_name, tag_value
    Cloud.compute.servers.all("tag:#{tag_name}" => tag_value).select{|s| RUNNING_SERVER_STATES.include?(s.state)}.map {|s| new s }
  end

  def creator
    @creator ||= fog_object.tags["Creator"]
  end

  def add_tag key, val
    try_for(TAG_CREATION_TIMEOUT) do
      Cloud.compute.tags.create(:resource_id => id, :key => key, :value => val)
    end
  end

  def configure_for_database database, password
    ssh.write(database.db_environment_file(password), '/tmp/envfile')
    ssh.run('sudo mv /tmp/envfile /etc/environment')
  end
  
  def resize_disk
    ssh.run('sudo resize2fs -p /dev/sda1')
  end

  def username
    fog_object.tags['Username'] || 'ubuntu'
  end

  def ssh_port
    fog_object.tags['SSHPort'] || '22'
  end

  def ssh
    Gofer::Host.new(public_ip_address, username, :port => ssh_port, :key_data => [File.read(Cloud.keyfile_path(key_name))], :paranoid => false, :quiet => true)
  end

  def wait_until_ready ssh_timeout=DEFAULT_SSH_CONNECTION_TIMEOUT
    super()
    Inform.debug("%{id} online at %{ip}, waiting for SSH connection...", :id => id, :ip => public_ip_address)
    wait_for_ssh ssh_timeout
    Inform.debug("Connected to %{id} via SSH successfully", :id => id)
  end

  def create_ami ami_name
    image_id = Cloud.compute.create_image(id, ami_name, "Created by #{ENV['USER']} on #{Time.now.strftime("%Y-%m-%d")}").body['imageId']

    Inform.debug("Created image at %{id}, waiting for AWS to recognize it...", :id => image_id)
    # Sometimes takes a while for AWS to realise there's a new image...
    image = Timeout::timeout(AMI_RECOGNITION_TIMEOUT) do
      image = nil
      while image == nil
        image = Cloud.compute.images.get(image_id)
      end
      image
    end
    Inform.debug("Image recognized, waiting for it to become available...")

    image.wait_for { state == 'available' }
    Inform.debug("Image available, sharing with other accounts...")

    Account.user_ids.each do |user_id|
      Inform.debug("Sharing %{id} with %{user_id}", :id => image_id, :user_id => user_id)
      Cloud.compute.modify_image_attributes(image_id, 'launchPermission', 'add', 'UserId' => user_id)
    end
    image_id
  end

  def credentials
    @credentials ||= if key_name
      keyfile_path = Cloud.keyfile_path(key_name)

      sanitize_key_file(key_name, keyfile_path)

      "-i #{keyfile_path} -o Port=#{ssh_port} -o StrictHostKeyChecking=no #{username}@#{public_ip_address}"
    else
      Inform.warning("Server %{id} has no key and therefore can not be accessed.", :id => id)
      false
    end
  end

  private

  def sanitize_key_file name, path
    begin
      stat = File.stat(path)
      raise "Keyfile at #{keyfile_path} not owned by #{ENV['USER']}, can't SSH" if stat.uid != Process.euid
      if (stat.mode & 077) != 0
        Inform.info("Changing permissions on key at %{path} to 0600", :path => path) do
          File.chmod(0600, path)
        end
      end
    rescue Errno::ENOENT
      raise "Can't find keyfile for #{name} under this account/region (looking in #{path})"
    end
  end

  def wait_for_ssh timeout
    try_for(timeout) {
      begin
        Timeout::timeout(15) do
          ssh.run('uptime')
        end
      # SshTimeout magic is here due to a weird bug with Ruby 1.8.7 where the Timeout::Error
      # will not be caught by wait_for_proc!
      rescue Timeout::Error => e
        raise "SSH Timeout Encountered: #{e.to_s}"
      end
    }
  end

  def try_for(timeout, &block)
    start_time = Time.now
    time_spent = 0
    success = false
    last_exception = nil
    while !success && time_spent < timeout
      begin
        block.call
        success = true
      rescue => e
        time_spent = Time.now - start_time
        Inform.debug("Exception: %{m} (%{c}) after %{time_spent}s (retrying until %{timeout}s)...", :c => e.class.to_s, :m => e.message, :time_spent => time_spent.to_i, :timeout => timeout)
        sleep 1
        last_exception = e
      end
    end
    #raise unless success
    raise last_exception unless success
  end

end
