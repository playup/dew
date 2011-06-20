class Password

  def self.random length=12
    (0...length).map{ ('a'..'z').to_a[rand(26)] }.join
  end

end