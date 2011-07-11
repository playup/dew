# Monkey patch clamp to remove duplicate options from help
module Clamp::Option::Declaration
  alias_method :non_uniq_documented_options, :documented_options
  def documented_options
    non_uniq_documented_options.uniq
  end
end


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
