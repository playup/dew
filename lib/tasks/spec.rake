require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "./spec/**/*_spec.rb"
  # Put spec opts in a file named .rspec in root
end

namespace :spec do
  desc "Run tests with coverage check"
  task :covered do
    ENV['RSPEC_COVERED'] = '1'
    Rake::Task['spec'].execute
  end
end