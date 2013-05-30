require 'spec_helper'

describe 'aws-ha-release' do
  let(:opts) do
    {
      as_group_name: 'test_group',
      aws_access_key: 'testaccesskey',
      aws_secret_key: 'testsecretkey',
      region: 'test-region'
    }
  end

  before do
    AWS.stub(:config)
    AWS::AutoScaling.stub(:new).and_return(AWS::FakeAutoScaling.new)
  end

  describe '#initialize' do
    it 'initializes the AWS connection'
    it 'ensures the as group exists'
  end
end
