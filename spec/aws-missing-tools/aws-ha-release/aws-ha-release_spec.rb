require 'spec_helper'

describe 'aws-ha-release' do
  let(:opts) { %w(-a test_group -o testaccesskey -s testsecretkey -r test_region -i 1 -t 0) }

  let(:as) { AWS::FakeAutoScaling.new }

  let(:instance_one) { AWS::FakeAutoScaling::Instance.new(@group) }

  let(:instance_two) { AWS::FakeAutoScaling::Instance.new(@group) }

  before do
    AWS::AutoScaling.stub(:new).and_return(as)
    IO.any_instance.stub(:puts)
  end

  describe '#initialize' do
    it 'initializes the AWS connection' do
      as.groups.create opts[1]

      AWS.should_receive(:config).with(access_key_id: 'testaccesskey', secret_access_key: 'testsecretkey', region: 'test_region')
      AwsMissingTools::AwsHaRelease.new(opts)
    end

    it 'ensures the as group exists' do
      lambda {
        opts[1] = 'fake_group'
        AwsMissingTools::AwsHaRelease.new(opts)
      }.should raise_error
    end
  end

  describe '#parse_options' do
    it 'requires the autoscaling group name to be passed in' do
      expect{ AwsMissingTools::AwsHaRelease.parse_options([]) }.to raise_error OptionParser::MissingArgument
      expect(AwsMissingTools::AwsHaRelease.parse_options(%w(-a test_group))[:as_group_name]).to eq 'test_group'
      expect(AwsMissingTools::AwsHaRelease.parse_options(%w(--as-group-name test_group))[:as_group_name]).to eq 'test_group'
    end

    it 'sets default options' do
      options = AwsMissingTools::AwsHaRelease.parse_options(%w(-a test_group))
      expect(options[:elb_timeout]).not_to be_nil
      expect(options[:region]).not_to be_nil
      expect(options[:inservice_time_allowed]).not_to be_nil
      expect(options[:aws_access_key]).not_to be_nil
      expect(options[:aws_secret_key]).not_to be_nil
    end

    context 'optional params' do
      it 'ELB timeout' do
        [%w(-a test_group -t 10), %w(-a test_group --elb-timeout 10)].each do |options|
          expect(AwsMissingTools::AwsHaRelease.parse_options(options)[:elb_timeout]).to eq 10
        end
      end

      it 'region' do
        [%w(-a test_group -r test_region), %w(-a test_group --region test_region)].each do |options|
          expect(AwsMissingTools::AwsHaRelease.parse_options(options)[:region]).to eq 'test_region'
        end
      end

      it 'inservice time allowed' do
        [%w(-a test_group -i 300), %w(-a test_group --inservice-time-allowed 300)].each do |options|
          expect(AwsMissingTools::AwsHaRelease.parse_options(options)[:inservice_time_allowed]).to eq 300
        end
      end

      it 'aws_access_key and aws_secret_key' do
        expect{ AwsMissingTools::AwsHaRelease.parse_options(%w(-a test_group -o testkey)) }.to raise_error OptionParser::MissingArgument
        expect{ AwsMissingTools::AwsHaRelease.parse_options(%w(-a test_group -s testsecretkey)) }.to raise_error OptionParser::MissingArgument

        options = AwsMissingTools::AwsHaRelease.parse_options(%w(-a test_group -o testkey -s testsecretkey))
        expect(options[:aws_access_key]).to eq 'testkey'
        expect(options[:aws_secret_key]).to eq 'testsecretkey'
      end
    end
  end

  describe '#execute!' do
    before do
      @group = as.groups.create opts[1]
      @aws_ha_release = AwsMissingTools::AwsHaRelease.new(opts)
    end

    it 'suspends certain autoscaling processes' do
      AWS::FakeAutoScaling::Group.any_instance.should_receive(:suspend_processes)
          .with(%w(ReplaceUnhealthy AlarmNotification ScheduledActions AZRebalance))
      @aws_ha_release.execute!
    end

    it 'requires certain autoscaling processes to not be suspended' do
      @aws_ha_release.group.suspend_processes %w(RemoveFromLoadBalancerLowPriority Terminate Launch HealthCheck AddToLoadBalancer)
      expect{ @aws_ha_release.execute! }.to raise_error
    end

    it 'adjusts the max size as well as the desired capacity if the desired capacity is equal to it' do
      @group.update(max_size: 1, desired_capacity: 1)

      @aws_ha_release.group.should_receive(:update).with(max_size: 2).ordered.and_call_original
      @aws_ha_release.group.should_receive(:update).with(desired_capacity: 2).ordered.and_call_original
      @aws_ha_release.group.should_receive(:update).with(desired_capacity: 1).ordered.and_call_original
      @aws_ha_release.group.should_receive(:update).with(max_size: 1).ordered.and_call_original
      @aws_ha_release.execute!
    end

    it 'only adjusts the desired capacity if max size does not equal desired capacity' do
      @aws_ha_release.group.should_receive(:update).with(desired_capacity: 2).ordered.and_call_original
      @aws_ha_release.group.should_receive(:update).with(desired_capacity: 1).ordered.and_call_original
      @aws_ha_release.execute!
    end
  end

  describe 'determining if instances are in service' do
    before do
      @group = as.groups.create opts[1]
      @group.update(desired_capacity: 2)
      @aws_ha_release = AwsMissingTools::AwsHaRelease.new(opts)
    end

    it 'checks all instances across a given load balancer' do
      load_balancer = AWS::FakeELB::LoadBalancer.new 'test_load_balancer_01', [
        {
          instance: instance_one,
          healthy: true
        },
        {
          instance: instance_two,
          healthy: false
        }
      ]

      expect(@aws_ha_release.instances_inservice?(load_balancer)).to eq false

      load_balancer.instances.make_instance_healthy(instance_two)
      expect(@aws_ha_release.instances_inservice?(load_balancer)).to eq true
    end

    it 'checks all instances across an array of load balancers' do
      load_balancers = [
        AWS::FakeELB::LoadBalancer.new('test_load_balancer_01', [
          {
            instance: instance_one,
            healthy: true
          },
          {
            instance: instance_two,
            healthy: false
          }
        ]), AWS::FakeELB::LoadBalancer.new('test_load_balancer_02', [
          {
            instance: instance_one,
            healthy: true
          },
          {
            instance: instance_two,
            healthy: false
          }
        ])
      ]

      expect(@aws_ha_release.all_instances_inservice?(load_balancers)).to eq false

      load_balancers[0].instances.make_instance_healthy(instance_two)
      expect(@aws_ha_release.all_instances_inservice?(load_balancers)).to eq false

      load_balancers[1].instances.make_instance_healthy(instance_two)
      expect(@aws_ha_release.all_instances_inservice?(load_balancers)).to eq true
    end

    it 'requires the number of inservice instances to match the desired capacity' do
      load_balancer = AWS::FakeELB::LoadBalancer.new 'test_load_balancer_01', [
        {
          instance: instance_one,
          healthy: true
        },
        {
          instance: instance_two,
          healthy: true
        }
      ]

      @group.update(desired_capacity: 3)

      expect(@aws_ha_release.instances_inservice?(load_balancer)).to eq false

      instance_three = AWS::FakeAutoScaling::Instance.new(@group)
      load_balancer.instances.register instance_three
      load_balancer.instances.make_instance_healthy(instance_three)

      expect(@aws_ha_release.instances_inservice?(load_balancer)).to eq true
    end
  end

  describe '#deregister_instance' do
    before do
      @group = as.groups.create opts[1]
      @aws_ha_release = AwsMissingTools::AwsHaRelease.new(opts)
    end

    it 'deregisters an instance across all load balancers' do
      elb_one = AWS::FakeELB::LoadBalancer.new 'test_load_balancer_01', [
        {
          instance: instance_one,
          healthy: true
        },
        {
          instance: instance_two,
          healthy: true
        }
      ]
      elb_two = AWS::FakeELB::LoadBalancer.new 'test_load_balancer_02', [
        {
          instance: instance_one,
          healthy: true
        },
        {
          instance: instance_two,
          healthy: true
        }
      ]

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
