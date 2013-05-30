require 'rspec'
require 'aws-missing-tools'

Dir['spec/support/**/*.rb'].each { |f| require File.expand_path(f) }

RSpec.configure do |config|
  config.order = 'random'
end
