class ConsoleCommand < Clamp::Command
  def execute
    load File.expand_path(File.join(File.dirname(__FILE__), 'console', 'irb_override.rb'))
    ARGV.reject! { true }
    puts <<-EOS
===============================================================
Objects available: -

Cloud          - Cloud Handle
Cloud.compute  - Access AWS EC2 (Elastic Compute Cloud) instances
Cloud.elb      - Access AWS ELB (Elastic Load Balancers)
Cloud.rds      - Access AWS RDS (Relational Database Service)
===============================================================
EOS
    IRB.start_session(binding)
  end
end