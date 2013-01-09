# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "dew/version"

description = <<TEXT
Dew is a layer between fog and the ground
TEXT


Gem::Specification.new do |s|
  s.name        = "dew"
  s.summary     = %q{Uses fog to access the cloud}
  s.description = description
  s.homepage    = "http://github.com/playup/dew"
  s.authors     = ["PlayUp Devops"]
  s.email       = ["devops@playup.com"]

  s.version     = Dew::VERSION
  s.platform    = Gem::Platform::RUBY

  s.add_runtime_dependency("inform", "~> 0.0.5")
  s.add_runtime_dependency("clamp", "~> 0.2.3")
  s.add_runtime_dependency("fog", ">= 1.1.2","< 1.9")
  s.add_runtime_dependency("gofer", "~> 0.2.5")
  s.add_runtime_dependency("highline", "~> 1.6.2")
  s.add_runtime_dependency("terminal-table", "~> 1.4.3")
  s.add_runtime_dependency("opensrs")
  s.add_runtime_dependency("nokogiri")

  s.add_development_dependency("rake", "~> 0.8.7")
  s.add_development_dependency("rspec", "~> 2.6.0")
  s.add_development_dependency("cucumber", "~> 0.10.3")
  s.add_development_dependency("simplecov", "~> 0.4.0")
  s.add_development_dependency("flay", "~> 1.4.2")
  s.add_development_dependency("geminabox")

  s.require_paths = ["lib"]
  s.files         = Dir["lib/**/*", "README.md", "LICENSE", 'example/**/*']
  s.test_files    = Dir["Rakefile", "spec/**/*", "features/**/*", "config/cucumber.yaml"]
  s.executables   = ["dew"]
end
