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
      as.groups.create opts[:as_group_name]

      AWS.should_receive(:config).with(access_key_id: 'testaccesskey', secret_access_key: 'testsecretkey', region: 'test-region')
      AwsHaRelease.new(opts)
    end

    it 'ensures the as group exists' do
      lambda {
        AwsHaRelease.new(opts.merge!(as_group_name: 'fake_group'))
      }.should raise_error
    end
  end

  describe '#execute!' do
    before do
      @group = as.groups.create opts[:as_group_name]
      @aws_ha_release = AwsHaRelease.new(opts)
    end

    it 'suspends certain autoscaling processes' do
      AWS::FakeAutoScaling::Group.any_instance.should_receive(:suspend_processes)
          .with('ReplaceUnhealthy', 'AlarmNotification', 'ScheduledActions', 'AZRebalance')
      @aws_ha_release.execute!
    end

    it 'adjusts the maximum size if the desired capacity is equal to it' do
      @group.update(max_size: 1, desired_capacity: 1)
      expect(@aws_ha_release.max_size_change).to eq 0

      @aws_ha_release.execute!

      expect(@group.max_size).to eq 2
      expect(@aws_ha_release.max_size_change).to eq 1
    end

    it 'increases the desired capacity by 1' do
      @aws_ha_release.execute!

      expect(@group.desired_capacity).to eq 2
    end
  end
end
