#!/usr/bin/env ruby

begin
  require 'aws-sdk'
  require 'trollop'
rescue LoadError => e
  puts "The #{e.message.split('-').last.strip} gem must be installed."
  raise
end

opts = Trollop::options do
  opt :as_group_name, 'AutoScaling Group Name', type: :string, short: '-a'
  opt :region, 'Region', default: 'us-east-1', type: :string, short: '-r'
  opt :elb_timeout, 'ELB Timeout', type: :int, default: 60, short: '-t'
  opt :inservice_time_allowed, 'InService Time Allowed', type: :int, default: 300, short: '-i'
  opt :aws_access_key, 'AWS Access Key', type: :string, short: '-o'
  opt :aws_secret_key, 'AWS Secret Key', type: :string, short: '-s'
end

Trollop::die :as_group_name, 'You must specify the AutoScaling Group Name: aws-ha-release.rb -a <group name>' unless opts[:as_group_name]
Trollop::die :aws_access_key, 'If you specify the AWS Secret Key, you must also specify the Access Key with -o <key>.' if opts[:aws_secret_key] && opts[:aws_access_key].nil?
Trollop::die :aws_secret_key, 'If you specify the AWS Access Key, you must also specify the Secret Key with -s <key>.' if opts[:aws_access_key] && opts[:aws_secret_key].nil?

if opts[:aws_access_key].nil? || opts[:aws_secret_key].nil?
  opts[:aws_access_key] = ENV['AWS_ACCESS_KEY']
  opts[:aws_secret_key] = ENV['AWS_SECRET_KEY']
end
