require 'aruba/cucumber'
require 'aws-sdk'

Before do
  AWS.stub!
end
