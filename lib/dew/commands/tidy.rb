class TidyCommand < Clamp::Command

  option ['--[no-]clean-environments'], :flag, "Clean up environments", :default => true
  option ['--[no-]clean-amis'], :flag, "Clean up AMIs", :default => true
  option ['--noop'], :flag, "Print out what we'd do instead of doing it", :default => false
  
  def tidy_environments
    Inform.info("Tidying up Environments...")
    names = Cloud.valid_servers.collect(&:tags).collect { |h| h['Environment'] if h['Environment'] }
    names << Cloud.rds.servers.all.select {|a| a.state == 'available'}.map(&:id)
    names = names.flatten.uniq
    names = names.grep /^cuke-/
    names.each do |name|
      Inform.info("Destroying environment #{name}")
      Environment.get(name).destroy unless noop?
    end
  end
 
  def tidy_amis
    Inform.info("Tidying up AMIS...")
    amis = Cloud.compute.images.all
    amis = amis.select {|a| a.name =~ /^cuke-/}
    amis.each do |ami|
      Inform.info("Destroying ami #{ami.name}") do
        ami.deregister unless noop?
      end
    end
  end
    
  def execute
    Inform.warning("--noop passed, no changes will be made!") if noop?
    tidy_environments if clean_environments?
    tidy_amis if clean_amis?
  end
end
