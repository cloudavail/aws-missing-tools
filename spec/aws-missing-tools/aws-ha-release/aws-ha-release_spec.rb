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

    context 'determining if instances are in service' do
      it 'checks all instances across a given load balancer' do
        load_balancer = AWS::FakeELB::LoadBalancer.new 'test_load_balancer_01'

        expect(@aws_ha_release.instances_inservice?(load_balancer)).to eq false

        load_balancer.instances.health[1] = {
          instance: AWS::FakeEC2::Instance.new,
          description: 'N/A',
          state: 'InService',
          reason_code: 'N/A'
        }

        expect(@aws_ha_release.instances_inservice?(load_balancer)).to eq true
      end

      it 'checks all instances across an array of load balancers' do
        load_balancers = [AWS::FakeELB::LoadBalancer.new('test_load_balancer_01'), AWS::FakeELB::LoadBalancer.new('test_load_balancer_02')]

        expect(@aws_ha_release.all_instances_inservice?(load_balancers)).to eq false

        load_balancers[0].instances.health[1] = {
          instance: AWS::FakeEC2::Instance.new,
          description: 'N/A',
          state: 'InService',
          reason_code: 'N/A'
        }

        expect(@aws_ha_release.all_instances_inservice?(load_balancers)).to eq false

        load_balancers[1].instances.health[1] = {
          instance: AWS::FakeEC2::Instance.new,
          description: 'N/A',
          state: 'InService',
          reason_code: 'N/A'
        }

        expect(@aws_ha_release.all_instances_inservice?(load_balancers)).to eq true
      end
    end
  end

  describe '#deregister_instance' do
    before do
      @group = as.groups.create opts[:as_group_name]
      @aws_ha_release = AwsHaRelease.new(opts)
    end

    it 'deregisters an instance across all load balancers' do
      instance_one = AWS::FakeEC2::Instance.new
      instance_two = AWS::FakeEC2::Instance.new

      elb_one = AWS::FakeELB::LoadBalancer.new 'test_load_balancer_01'
      elb_two = AWS::FakeELB::LoadBalancer.new 'test_load_balancer_02'

      elb_one.instances.register instance_one
      elb_one.instances.register instance_two

      elb_two.instances.register instance_one
      elb_two.instances.register instance_two

      @aws_ha_release.deregister_instance instance_one, [elb_one, elb_two]

      expect(elb_one.instances).not_to include instance_one
      expect(elb_two.instances).not_to include instance_one
    end
  end
end
