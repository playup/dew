class FogModel
  def initialize fog_object
    @fog_object = fog_object
  end
  
  def id
    @fog_object.id
  end
  
  def wait_until_ready
    @fog_object.wait_for { ready? }
  end
  
  def method_missing method_sym, *args, &block
    @fog_object.send(method_sym, *args, &block)
  end
  
  protected
  
  def fog_object
    @fog_object
  end
end