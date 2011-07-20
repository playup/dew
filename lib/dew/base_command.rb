class DewBaseCommand < Clamp::Command
  def configure
    $debug = debug?
    Inform.level = quiet? ? :warning : (verbose? ? :debug : :info)
    Cloud.region = region
    Cloud.account_name = account
  end

  def execute
    configure
    super
  end
end
