require 'spec_helper'

module AwsMissingTools
  class AwsHaRelease
    describe CycleServers do
      let(:opts) do
        {
          as_group_name:          'test_group',
          aws_access_key:         'testaccesskey',
          aws_secret_key:         'testsecretkey',
          region:                 'test_region',
          inservice_time_allowed: 1,
          elb_timeout:            0,
          min_inservice_time:     5
        }
      end

      let(:as) { AWS::FakeAutoScaling.new }
      let(:instance_one) { AWS::FakeAutoScaling::Instance.new(group) }
      let(:instance_two) { AWS::FakeAutoScaling::Instance.new(group) }

      let!(:group) { as.groups.create opts[:as_group_name] }

      before do
        allow(AWS::AutoScaling).to receive(:new).and_return(as)

        logfile = instance_double('File')
        allow(File).to receive(:open).and_return(logfile)
        allow(logfile).to receive(:sync=)

        allow(Logger).to receive(:new).and_return(Logger.new('/dev/null'))

        allow_any_instance_of(CycleServers).to receive(:sleep)
      end

      describe '#initialize' do
        it 'initializes the AWS connection' do
          as.groups.create opts[:as_group_name]

          expect(AWS).to receive(:config).with(access_key_id: 'testaccesskey', secret_access_key: 'testsecretkey', region: 'test_region', max_retries: 20)
          CycleServers.new(opts)
        end

        it 'ensures the as group exists' do
          expect {
            opts[:as_group_name] = 'fake_group'
            CycleServers.new(opts)
          }.to raise_error
        end

        context 'number of simultaneous instances' do
          before do
            as.groups.create opts[:as_group_name]
          end

          it 'with MAX, sets the option to the number of active instances' do
            opts.merge!(num_simultaneous_instances: 'MAX')
            expect(CycleServers.new(opts).instance_variable_get('@opts')[:num_simultaneous_instances]).to eq 2
          end

          it 'with an integer, sets the option to that integer' do
            opts.merge!(num_simultaneous_instances: '1')
            expect(CycleServers.new(opts).instance_variable_get('@opts')[:num_simultaneous_instances]).to eq 1
          end
        end
      end

      describe '#cycle' do
        let(:cycle_servers) { CycleServers.new(opts) }

        before do
          allow(cycle_servers).to receive(:all_instances_inservice_for_time_period?).and_return(true)
        end

        it 'suspends certain autoscaling processes' do
          expect_any_instance_of(AWS::FakeAutoScaling::Group).to receive(:suspend_processes)
              .with(%w(ReplaceUnhealthy AlarmNotification ScheduledActions AZRebalance))

          cycle_servers.cycle
        end

        it 'requires certain autoscaling processes to not be suspended' do
          group.suspend_processes %w(RemoveFromLoadBalancerLowPriority Terminate Launch HealthCheck AddToLoadBalancer)
          expect { cycle_servers.cycle }.to raise_error
        end

        it 'adjusts the max size as well as the desired capacity if the desired capacity is equal to it' do
          group.update(max_size: 1, desired_capacity: 1)

          expect(group).to receive(:update).with(max_size: 2, desired_capacity: 2).ordered.and_call_original
          expect(group).to receive(:update).with(desired_capacity: 1, max_size: 1).ordered.and_call_original
          cycle_servers.cycle
        end

        it 'only adjusts the desired capacity if max size does not equal desired capacity' do
          expect(group).to receive(:update).with(desired_capacity: 2).ordered.and_call_original
          expect(group).to receive(:update).with(desired_capacity: 1).ordered.and_call_original
          cycle_servers.cycle
        end

        it 'does not deregister instances if cycling with a custom health check' do
          custom_health_check = -> { true }
          cycle_servers = CycleServers.new(opts, &custom_health_check)

          expect(cycle_servers).not_to receive(:deregister_instance)
          cycle_servers.cycle
        end
      end

      describe 'determining if instances are in service' do
        let(:cycle_servers) { CycleServers.new(opts) }

        before do
          group.update(desired_capacity: 2)
          cycle_servers.instance_variable_set :@desired_capacity, 2
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

          expect(cycle_servers.instances_inservice?(load_balancer)).to eq false

          load_balancer.instances.make_instance_healthy(instance_two)
          expect(cycle_servers.instances_inservice?(load_balancer)).to eq true
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

          expect(group).to receive(:load_balancers).at_least(:once).and_return(load_balancers)
          expect(cycle_servers.all_instances_inservice?).to eq false

          load_balancers[0].instances.make_instance_healthy(instance_two)
          expect(cycle_servers.all_instances_inservice?).to eq false

          load_balancers[1].instances.make_instance_healthy(instance_two)
          expect(cycle_servers.all_instances_inservice?).to eq true
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

          cycle_servers.instance_variable_set :@desired_capacity, 3
          group.update(desired_capacity: 3)

          expect(cycle_servers.instances_inservice?(load_balancer)).to eq false

          instance_three = AWS::FakeAutoScaling::Instance.new(group)
          load_balancer.instances.register instance_three
          load_balancer.instances.make_instance_healthy(instance_three)

          expect(cycle_servers.instances_inservice?(load_balancer)).to eq true
        end

        # ELB health checks seems to be reporting the EC2 health status for a short period of time before switching to the
        # ELB check. This is a false positive and, until Amazon implements a fix, we must work around it
        # see https://forums.aws.amazon.com/message.jspa?messageID=455646
        it 'ensures that an instance has been in service for a period of time before considering it healthy' do
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
            ])
          ]

          expect(group).to receive(:load_balancers).at_least(:once).and_return(load_balancers)
          expect(cycle_servers.all_instances_inservice_for_time_period?).to eq false

          load_balancers[0].instances.make_instance_healthy instance_two
          expect(cycle_servers.all_instances_inservice_for_time_period?).to eq false

          # time_spent_inservice advances on each call. by this call, it has advanced beyond the minimum
          expect(cycle_servers.all_instances_inservice_for_time_period?).to eq true
        end

        it 'accepts a custom health check and calls it' do
          custom_health_check = -> { true }
          cycle_servers       = CycleServers.new(opts, &custom_health_check)

          expect(custom_health_check).to receive(:call).and_call_original
          expect(group).not_to receive(:load_balancers)

          expect(cycle_servers.all_instances_inservice?).to eq true
        end
      end

      describe '#deregister_instance' do
        let(:cycle_servers) { CycleServers.new(opts) }

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

          cycle_servers.deregister_instance instance_one, [elb_one, elb_two]

          expect(elb_one.instances).not_to include instance_one
          expect(elb_two.instances).not_to include instance_one
        end
      end

      describe '#max_size_change' do
        it 'does not change the desired capacity by default' do
          group.update(max_size: 4, desired_capacity: 2)
          cycle_servers = CycleServers.new(opts)

          expect(cycle_servers.max_size_change).to eq 0
        end

        it 'adjusts the max size when it is equal to the desired capacity' do
          group.update(max_size: 2, desired_capacity: 2)
          cycle_servers = CycleServers.new(opts)

          expect(cycle_servers.max_size_change).to eq 1
        end

        describe 'accounts for num_simultaneous_instances' do
          let(:cycle_servers) { CycleServers.new(opts.merge(num_simultaneous_instances: 2)) }

          it 'grows by up to the number specified' do
            group.update(max_size: 2, desired_capacity: 2)
            expect(cycle_servers.max_size_change).to eq 2
          end

          it 'grows by less than the number specified if more are not necessary' do
            group.update(max_size: 3, desired_capacity: 2)
            expect(cycle_servers.max_size_change).to eq 1
          end

          it 'does not grow at all if not necessary' do
            group.update(max_size: 4, desired_capacity: 2)
            expect(cycle_servers.max_size_change).to eq 0
          end
        end
      end
    end
  end
end
