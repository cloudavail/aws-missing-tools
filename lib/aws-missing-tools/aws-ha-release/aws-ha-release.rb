require 'timeout'
require 'optparse'

class AwsHaRelease
  attr_reader :group

  def initialize(argv)
    @opts = AwsHaRelease.parse_options(argv)

    AWS.config(access_key_id: @opts[:aws_access_key], secret_access_key: @opts[:aws_secret_key], region: @opts[:region])

    @as = AWS::AutoScaling.new
    @group = @as.groups[@opts[:as_group_name]]

    if @group.nil?
      raise ArgumentError, "The Auto Scaling Group named #{@opts[:as_group_name]} does not exist in #{@opts[:region]}."
    end

    @max_size_change = 0
    @inservice_polling_time = 10
    @processes_to_suspend = %w(ReplaceUnhealthy AlarmNotification ScheduledActions AZRebalance)
  end

  def self.parse_options(arguments)
    options = {
      region: 'us-east-1',
      elb_timeout: 60,
      inservice_time_allowed: 300
    }

    OptionParser.new do |opts|
      opts.banner = 'Usage: aws-ha-release.rb -a <group name> [options]'

      opts.on('-a', '--as-group-name GROUP_NAME', 'AutoScaling Group Name') do |v|
        options[:as_group_name] = v
      end

      opts.on('-r', '--region REGION', 'Region') do |v|
        options[:region] = v
      end

      opts.on('-t', '--elb-timeout TIME', 'ELB Timeout (seconds)') do |v|
        options[:elb_timeout] = v.to_i
      end

      opts.on('-i', '--inservice-time-allowed TIME', 'Time allowed for instance to come in service (seconds)') do |v|
        options[:inservice_time_allowed] = v.to_i
      end

      opts.on('-o', '--aws_access_key AWS_ACCESS_KEY', 'AWS Access Key') do |v|
        options[:aws_access_key] = v
      end

      opts.on('-s', '--aws_secret_key AWS_SECRET_KEY', 'AWS Secret Key') do |v|
        options[:aws_secret_key] = v
      end
    end.parse!(arguments)

    raise OptionParser::MissingArgument, 'You must specify the AutoScaling Group Name: aws-ha-release.rb -a <group name>' if options[:as_group_name].nil?

    if options[:aws_secret_key] && options[:aws_access_key].nil? || options[:aws_access_key] && options[:aws_secret_key].nil?
      raise OptionParser::MissingArgument, 'If specifying either the AWS Access or Secret Key, then the other must also be specified. aws-ha-release.rb -a <group name> -o access_key -s secret_key'
    elsif options[:aws_secret_key].nil? && options[:aws_access_key].nil?
      options[:aws_access_key] = ENV['AWS_ACCESS_KEY']
      options[:aws_secret_key] = ENV['AWS_SECRET_KEY']
    end

    options
  end

  def execute!
    %w(RemoveFromLoadBalancerLowPriority Terminate Launch HealthCheck AddToLoadBalancer).each do |process|
      if @group.suspended_processes.keys.include? process
        raise "AutoScaling process #{process} is currently suspended on #{@group.name} but is necessary for this script."
      end
    end

    @group.suspend_processes @processes_to_suspend

    if @group.max_size == @group.desired_capacity
      puts "#{@group.name} has a max-size of #{@group.max_size}. In order to recycle instances max-size will be temporarily increased by 1."
      @group.update(max_size: @group.max_size + 1)
      @max_size_change = 1
    end

    @group.update(desired_capacity: @group.desired_capacity + 1)

    puts "The list of Instances in Auto Scaling Group #{@group.name} that will be terminated is:\n#{@group.ec2_instances.map(&:id)}"
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

          puts "Instance #{instance.id} will now be terminated. By terminating this instance, the actual capacity will be decreased to 1 under desired-capacity."
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
    return false if load_balancer.instances.count != @group.desired_capacity

    load_balancer.instances.health.each do |instance_health|
      unless instance_health[:state] == 'InService'
        puts "Instance #{instance_health[:instance].id} is currently #{instance_health[:state]} on load balancer #{load_balancer.name}."

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
