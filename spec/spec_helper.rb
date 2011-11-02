
# From https://github.com/colszowka/simplecov#readme
if ENV['RSPEC_COVERED']
  require 'simplecov'
  SimpleCov.start 'rails' do
    # bug: changing the coverage_dir here breaks coverage recording.
    add_filter "/commands/"
    add_filter "/base_command.rb"

    at_exit do
      SimpleCov.result.format!
      if SimpleCov.result.covered_percent < 100
        $stderr.puts "Coverage not 100%, build failed."
        exit 1
      end
    end
  end
end

#require File.expand_path(File.join(File.dirname(__FILE__), '..', 'env'))
require 'dew'
Inform.level = :error
