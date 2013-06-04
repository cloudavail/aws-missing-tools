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
    @processes_to_suspend = %w(ReplaceUnhealthy AlarmNotification ScheduledActions AZRebalance)
  end

  def execute!
    @group.suspend_processes @processes_to_suspend

    if @group.max_size == @group.desired_capacity
      puts "#{@group.name} has a max-size of #{@group.max_size}. In order to recycle instances max-size will be temporarily increased by 1."
      @group.update(max_size: @group.max_size + 1)
      @max_size_change = 1
    end

    @group.update(desired_capacity: @group.desired_capacity + 1)

    puts "The list of Instances in Auto Scaling Group $asg_group_name that will be terminated is:\n#{@group.ec2_instances.map(&:id)}"
    @group.ec2_instances.each do |instance|
      time_taken = 0

      begin
        Timeout::timeout(@opts[:inservice_time_allowed]) do

          until all_instances_inservice?(@group.load_balancers)
            puts "#{time_taken} seconds have elapsed while waiting for an Instance to reach InService status."

            time_taken += @inservice_polling_time
            sleep @inservice_polling_time
          end

          deregister_instance instance, @group.load_balancers
          sleep @opts[:elb_timeout]
          instance.terminate false
        end
      rescue Timeout::Error => e
        puts "\nDuring the last #{time_taken} seconds, a new AutoScaling instance failed to become healthy."
        puts "The following settings were changed and will not be changed back by this script:\n"

        puts "AutoScaling processes #{@processes_to_suspend} were suspended."
        puts "The desired capacity was changed from #{@group.desired_capacity - 1} to #{@group.desired_capacity}."

        if @max_size_change > 0
          puts "The maximum size was changed from #{@group.max_size - @max_size_change} to #{@group.max_size}"
        end

        raise
      end
    end

    puts "#{@group.name} had its desired-capacity increased temporarily by 1 to a desired-capacity of #{@group.desired_capacity}."
    puts "$app_name will now return the desired-capacity of #{@group.name} to its original desired-capacity of #{@group.desired_capacity - 1}."
    @group.update(desired_capacity: @group.desired_capacity - 1)

    if @max_size_change > 0
      puts "\n#{@group.name} had its max_size increased temporarily by #{@max_size_change} to a max_size of #{@group.max_size}."
      puts "The max_size of #{@group.name} will now be returned to its original max_size of #{@group.max_size - @max_size_change}."

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
      unless health[:state] == 'InService'
        puts "Instance #{health[:instance].id} is currently #{health[:state]} on load balancer #{load_balancer.name}."

        return false
      end
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
