#!/usr/bin/env ruby

require 'pathname'

TIMES = 5

def tmp_dir
  @tmp_dir ||= Pathname(__FILE__).expand_path.parent.parent.parent.join('tmp')
end

def output_path
  @output_path ||= tmp_dir.join('stresstest', Time.now.strftime("%Y%m%d"))
end

def run_and_collate index, command
  run_dir = output_path.join("#{index}")
  run_dir.mkpath unless run_dir.exist?
  outfile = run_dir.join('out.txt')
  system "#{command} > '#{outfile}' 2>&1"
  run_result = $?.exitstatus
  system "mv #{tmp_dir.to_s.inspect}/*.log #{run_dir.to_s.inspect}"   # Keep the cucumber output
  if run_result == 0
    outfile.rename(outfile.dirname + 'pass.txt'); outfile = outfile.dirname + 'pass.txt'
    puts "Run #{index} passed, see #{outfile}"
    true
  else
    outfile.rename(outfile.dirname + 'fail.txt'); outfile = outfile.dirname + 'fail.txt'
    puts "Run #{index} failed, see #{outfile}"
    false
  end
end

def run
  command = ARGV.join(' ')
  raise "Syntax: #{__FILE__} command" if command == ''

  successes = 0

  (1..TIMES).map do |i|
    successes += 1 if run_and_collate(i, command)
  end

  if successes == TIMES
    puts "All runs succeeded"
  else
    puts "Only #{successes} / #{TIMES} runs succeeded"
    exit 1
  end
end

run

