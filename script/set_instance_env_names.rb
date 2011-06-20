#!/usr/bin/env ruby
# Some instances may have been created already without an Environment tag, this script will add that tag

require 'dew'

regions = %w(us-west-1 us-east-1 eu-west-1 ap-southeast-1 ap-northeast-1)
accounts = %w(development)

accounts.each { |account|
  regions.each { |region|
    Cloud.connect(region, account)
    Cloud.compute.servers.each { |s|
      h = {:resource_id => s.id, :key => 'Environment', :value => s.tags['Name'] || s.id} unless s.tags.has_key?('Environment')
      p Cloud.compute.tags.create(h) if h
    }
  }
}
