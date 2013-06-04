#!/usr/bin/env ruby

require 'aws-missing-tools'
AwsMissingTools::AwsHaRelease.new(ARGV.dup).execute!
