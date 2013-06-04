#!/usr/bin/env ruby

require 'aws-missing-tools'
AwsHaRelease.new(ARGV.dup).execute!
