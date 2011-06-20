require 'bundler'
Bundler::GemHelper.install_tasks

ROOT_DIR = File.expand_path(File.dirname(__FILE__))

require 'fileutils'

Dir[File.join(ROOT_DIR, 'lib', 'tasks', '*.rake')].each { |task| import task }

namespace :metrics do
  desc "Run the flay code duplication measurement over the app, lib and specs"
  task :flay do
    flay_out = File.join(ROOT_DIR, 'reports', 'flay.txt')
    FileUtils.mkdir_p(File.dirname(flay_out)) unless File.directory? File.dirname(flay_out)
    system "flay scripts lib spec > #{flay_out}"
    print "Flay: "
    system "head -n1 #{flay_out}"
    puts "Full flay output in #{flay_out}"
  end
end

task :default => "spec:covered"

task :flay do
  sh "flay lib spec script"
end
