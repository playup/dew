require 'timeout'
require 'pathname'

ROOT_DIR = Pathname(__FILE__).expand_path.parent.parent.parent
$: << (ROOT_DIR+'lib').to_s
require 'dew'

def tmp_dir
  tmp_dir = ROOT_DIR.join('tmp')
  tmp_dir.mkdir unless tmp_dir.exist?
  tmp_dir
end

def run_and_capture command, logname, timeout = 1200
  logfile = tmp_dir.join(logname + ".log")
  begin
    Timeout::timeout(timeout) do
      system("RUBYLIB='lib' #{command} > '#{logfile}' 2>&1")
    end
  rescue Timeout::Error => e
    $stderr.puts "*** Command #{command} took longer than #{timeout} seconds to run, log follows:"
    $stderr.puts logfile.read
    raise e
  end
  logfile
end

def unique_test_name
  "cuke-#{ENV['USER']}-#{Time.now.to_i}"
end

def environment
  @environment ||= Environment.get(@environment_name) if @environment_name
end

def elb
  @elb ||= Cloud.elb.describe_load_balancers(@environment_name).body['DescribeLoadBalancersResult']['LoadBalancerDescriptions'].first
end
