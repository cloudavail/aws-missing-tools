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

  let(:as) { AWS::FakeAutoScaling.new }

  before do
    AWS.stub(:config)
    AWS::AutoScaling.stub(:new).and_return(as)
  end

  describe '#initialize' do
    it 'initializes the AWS connection' do
      as.groups.create 'test_group'

      AWS.should_receive(:config).with(access_key_id: 'testaccesskey', secret_access_key: 'testsecretkey', region: 'test-region')
      AwsHaRelease.new(opts)
    end

    it 'ensures the as group exists' do
      lambda {
        AwsHaRelease.new(opts.merge!(as_group_name: 'fake_group'))
      }.should raise_error
    end
  end
end
