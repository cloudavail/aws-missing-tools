require 'optparse'

module AwsMissingTools
  class AwsHaRelease
    attr_reader :group

    PROCESSES_TO_SUSPEND = %w(ReplaceUnhealthy AlarmNotification ScheduledActions AZRebalance)
    INSERVICE_POLLING_TIME = 10

    def initialize(argv)
      STDOUT.sync = true

      @opts = AwsHaRelease.parse_options(argv)

      AWS.config(access_key_id: @opts[:aws_access_key], secret_access_key: @opts[:aws_secret_key], region: @opts[:region])

      @as = AWS::AutoScaling.new
      @group = @as.groups[@opts[:as_group_name]]

      if @group.nil?
        raise ArgumentError, "The Auto Scaling Group named #{@opts[:as_group_name]} does not exist in #{@opts[:region]}."
      end

      @max_size_change = 0
      @time_spent_inservice = 0
    end

    def self.parse_options(arguments)
      options = {
        region: 'us-east-1',
        elb_timeout: 60,
        inservice_time_allowed: 300,
        min_inservice_time: 30,
        num_simultaneous_instances: 1
      }

      OptionParser.new('Usage: aws-ha-release.rb -a <group name> [options]', 50) do |opts|
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

        opts.on('-m', '--min-inservice-time TIME', 'Minimum time an instance must be in service before it is considered healthy (seconds)') do |v|
          options[:min_inservice_time] = v.to_i
        end

        opts.on('-o', '--aws_access_key AWS_ACCESS_KEY', 'AWS Access Key') do |v|
          options[:aws_access_key] = v
        end

        opts.on('-s', '--aws_secret_key AWS_SECRET_KEY', 'AWS Secret Key') do |v|
          options[:aws_secret_key] = v
        end

        opts.on('-n', '--num-simultaneous-instances NUM', 'Number of instances to simultaneously bring up per iteration') do |v|
          options[:num_simultaneous_instances] = v.to_i
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

      @group.suspend_processes PROCESSES_TO_SUSPEND

      @max_size_change = determine_max_size_change
      if @max_size_change > 0
        puts "#{@group.name} has a max-size of #{@group.max_size}. In order to recycle instances max-size will be temporarily increased by #{@max_size_change}."
        @group.update(max_size: @group.max_size + @max_size_change)
      end

      @group.update(desired_capacity: @group.desired_capacity + @opts[:num_simultaneous_instances])

      puts "The list of instances in Auto Scaling Group #{@group.name} that will be terminated is:\n#{@group.auto_scaling_instances.map{ |i| i.ec2_instance.id }.to_ary}"
      @group.auto_scaling_instances.each_slice(@opts[:num_simultaneous_instances]) do |instances|
        time_taken = 0

        until all_instances_inservice_for_time_period?(@group.load_balancers, INSERVICE_POLLING_TIME)
          puts "#{time_taken} seconds have elapsed while waiting for all instances to be InService for a minimum of #{@opts[:min_inservice_time]} seconds."

          if time_taken >= @opts[:inservice_time_allowed]
            puts "\nDuring the last #{time_taken} seconds, a new AutoScaling instance failed to become healthy."
            puts "The following settings were changed and will not be changed back by this script:\n"

            puts "AutoScaling processes #{PROCESSES_TO_SUSPEND} were suspended."
            puts "The desired capacity was changed from #{@group.desired_capacity - @opts[:num_simultaneous_instances]} to #{@group.desired_capacity}."

            if @max_size_change > 0
              puts "The maximum size was changed from #{@group.max_size - @max_size_change} to #{@group.max_size}"
            end

            raise
          else
            time_taken += INSERVICE_POLLING_TIME
            sleep INSERVICE_POLLING_TIME
          end
        end

        puts "\nThe new instance(s) was/were found to be healthy; #{@opts[:num_simultaneous_instances]} old instance(s) will now be removed from the load balancers."
        instances.each { |instance| deregister_instance(instance.ec2_instance, @group.load_balancers) }

        puts "Sleeping for the ELB Timeout period of #{@opts[:elb_timeout]}"
        sleep @opts[:elb_timeout]

        puts "\nInstance(s) #{instances.map{ |i| i.ec2_instance.id }.join(', ')} will now be terminated. By terminating this/these instance(s), the actual capacity will be decreased to #{@opts[:num_simultaneous_instances]} under desired-capacity."
        instances.each { |instance| instance.terminate false }
      end

      puts "\n#{@group.name} had its desired-capacity increased temporarily by #{@opts[:num_simultaneous_instances]} to a desired-capacity of #{@group.desired_capacity}."
      puts "The desired-capacity of #{@group.name} will now be returned to its original desired-capacity of #{@group.desired_capacity - @opts[:num_simultaneous_instances]}."
      @group.update(desired_capacity: @group.desired_capacity - @opts[:num_simultaneous_instances])

      if @max_size_change > 0
        puts "\n#{@group.name} had its max_size increased temporarily by #{@max_size_change} to a max_size of #{@group.max_size}."
        puts "The max_size of #{@group.name} will now be returned to its original max_size of #{@group.max_size - @max_size_change}."

        @group.update(max_size: @group.max_size - @max_size_change)
        @max_size_change = 0
      end

      @group.resume_all_processes
    end

    def determine_max_size_change
      if @group.max_size - @group.desired_capacity < @opts[:num_simultaneous_instances]
        @group.desired_capacity + @opts[:num_simultaneous_instances] - @group.max_size
      else
        0
      end
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
          puts "\nInstance #{instance_health[:instance].id} is currently #{instance_health[:state]} on load balancer #{load_balancer.name}."

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

    def all_instances_inservice_for_time_period?(load_balancers, change_in_time)
      if all_instances_inservice?(load_balancers)
        if @time_spent_inservice >= @opts[:min_inservice_time]
          return true
        else
          puts "\nAll instances have been InService for #{@time_spent_inservice} seconds."

          @time_spent_inservice += change_in_time
          return false
        end
      else
        @time_spent_inservice = 0
        return false
      end
    end
  end
end
