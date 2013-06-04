require 'timeout'

class AwsHaRelease
  attr_reader :group

  def initialize(opts)
    AWS.config(access_key_id: opts[:aws_access_key], secret_access_key: opts[:aws_secret_key], region: opts[:region])

    @as = AWS::AutoScaling.new
    @group = @as.groups[opts[:as_group_name]]

    if @group.nil?
      raise ArgumentError, "The Auto Scaling Group named #{opts[:as_group_name]} does not exist in #{opts[:region]}."
    end

    @max_size_change = 0
    @inservice_polling_time = 10
    @opts = opts
  end

  def execute!
    @group.suspend_processes 'ReplaceUnhealthy', 'AlarmNotification', 'ScheduledActions', 'AZRebalance'

    if @group.max_size == @group.desired_capacity
      @group.update(max_size: @group.max_size + 1)
      @max_size_change = 1
    end

    @group.update(desired_capacity: @group.desired_capacity + 1)

    @group.ec2_instances.each do |instance|
      Timeout::timeout(@opts[:inservice_time_allowed]) do
        until all_instances_inservice?(@group.load_balancers)
          sleep @inservice_polling_time
        end

        deregister_instance instance, @group.load_balancers
        sleep @opts[:elb_timeout]
        instance.terminate false
      end
    end

    @group.update(desired_capacity: @group.desired_capacity - 1)

    if @max_size_change > 0
      @group.update(max_size: @group.max_size - @max_size_change)
      @max_size_change = 0
    end

    @group.resume_all_processes
  end

  def deregister_instance(instance, load_balancers)
    load_balancers.each do |load_balancer|
      load_balancer.instances.deregister instance
    end
  end

  def instances_inservice?(load_balancer)
    load_balancer.instances.health.each do |health|
      return false unless health[:state] == 'InService'
    end

    true
  end

  def all_instances_inservice?(load_balancers)
    load_balancers.each do |load_balancer|
      return false unless instances_inservice?(load_balancer)
    end

    true
  end
end
