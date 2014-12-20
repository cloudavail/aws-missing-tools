module AwsMissingTools
  class CycleServers < AwsHaRelease
    PROCESSES_TO_SUSPEND = %w(ReplaceUnhealthy AlarmNotification ScheduledActions AZRebalance)
    INSERVICE_POLLING_TIME = 10

    attr_reader :logger

    def initialize(options, &block)
      @opts = validate_options options

      if @opts[:log_output].is_a?(String)
        output = File.open(@opts[:log_output], File::WRONLY | File::CREAT | File::TRUNC)
        output.sync = true
      else
        # assume it's STDOUT or STDERR or similar
        output = @opts[:log_output]
      end
      @logger = Logger.new(output)
      @logger.level = @opts[:log_level]

      AWS.config(access_key_id: @opts[:aws_access_key], secret_access_key: @opts[:aws_secret_key], region: @opts[:region])
      @as = AWS::AutoScaling.new
      @group = @as.groups[@opts[:as_group_name]]

      if @group.nil?
        raise ArgumentError, "The Auto Scaling Group named #{@opts[:as_group_name]} does not exist in #{@opts[:region]}."
      end
      @opts[:num_simultaneous_instances] = Integer(@opts[:num_simultaneous_instances]) rescue @group.auto_scaling_instances.count

      @custom_health_check = block_given? ? block : nil

      @time_spent_inservice = 0
    end

    def cycle
      %w(RemoveFromLoadBalancerLowPriority Terminate Launch HealthCheck AddToLoadBalancer).each do |process|
        if @group.suspended_processes.keys.include? process
          raise "AutoScaling process #{process} is currently suspended on #{@group.name} but is necessary for this script."
        end
      end

      @group.suspend_processes PROCESSES_TO_SUSPEND

      if max_size_change > 0
        logger.warn "#{@group.name} has a max-size of #{@group.max_size}. In order to recycle instances max-size will be temporarily increased by #{max_size_change}."
        @group.update(max_size: @group.max_size + max_size_change)
      end

      @group.update(desired_capacity: @group.desired_capacity + @opts[:num_simultaneous_instances])

      logger.info "The list of instances in Auto Scaling Group #{@group.name} that will be terminated is:#{@group.auto_scaling_instances.map{ |i| i.ec2_instance.id }.to_ary}"
      logger.info "The number of instances that will be brought up simultaneously is: #{@opts[:num_simultaneous_instances]}"
      @group.auto_scaling_instances.to_a.each_slice(@opts[:num_simultaneous_instances]) do |instances|
        time_taken = 0

        until all_instances_inservice_for_time_period?
          logger.info "#{time_taken} seconds have elapsed while waiting for all instances to be InService for a minimum of #{@opts[:min_inservice_time]} seconds."

          if time_taken >= @opts[:inservice_time_allowed]
            logger.warn "During the last #{time_taken} seconds, a new AutoScaling instance failed to become healthy."
            logger.warn "The following settings were changed and will not be changed back by this script:"

            logger.warn "AutoScaling processes #{PROCESSES_TO_SUSPEND} were suspended."
            logger.warn "The desired capacity was changed from #{@group.desired_capacity - @opts[:num_simultaneous_instances]} to #{@group.desired_capacity}."

            if max_size_change > 0
              logger.warn "The maximum size was changed from #{@group.max_size - max_size_change} to #{@group.max_size}"
            end

            raise
          else
            time_taken += INSERVICE_POLLING_TIME
            sleep INSERVICE_POLLING_TIME
          end
        end

        logger.info "The new instance(s) was/were found to be healthy."

        if using_elb?
          logger.info "#{@opts[:num_simultaneous_instances]} old instance(s) will now be removed from the load balancers."
          instances.each { |instance| deregister_instance(instance.ec2_instance, @group.load_balancers) }

          logger.info "Sleeping for the ELB Timeout period of #{@opts[:elb_timeout]}"
          sleep @opts[:elb_timeout]
        end

        logger.info "Instance(s) #{instances.map{ |i| i.ec2_instance.id }.join(', ')} will now be terminated. By terminating this/these instance(s), the actual capacity will be decreased to #{@opts[:num_simultaneous_instances]} under desired-capacity."
        instances.each { |instance| instance.terminate false }
      end

      logger.info "#{@group.name} had its desired-capacity increased temporarily by #{@opts[:num_simultaneous_instances]} to a desired-capacity of #{@group.desired_capacity}."
      logger.info "The desired-capacity of #{@group.name} will now be returned to its original desired-capacity of #{@group.desired_capacity - @opts[:num_simultaneous_instances]}."
      @group.update(desired_capacity: @group.desired_capacity - @opts[:num_simultaneous_instances])

      if max_size_change > 0
        logger.warn "#{@group.name} had its max_size increased temporarily by #{max_size_change} to a max_size of #{@group.max_size}."
        logger.warn "The max_size of #{@group.name} will now be returned to its original max_size of #{@group.max_size - max_size_change}."

        @group.update(max_size: @group.max_size - max_size_change)
      end

      @group.resume_all_processes
    end

    def max_size_change
      @max_size_change ||= begin
        if @group.max_size - @group.desired_capacity < @opts[:num_simultaneous_instances]
          @group.desired_capacity + @opts[:num_simultaneous_instances] - @group.max_size
        else
          0
        end
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
          logger.info "Instance #{instance_health[:instance].id} is currently #{instance_health[:state]} on load balancer #{load_balancer.name}."

          return false
        end
      end

      true
    end

    def all_instances_inservice?
      if using_elb?
        @group.load_balancers.each do |load_balancer|
          return false unless instances_inservice?(load_balancer)
        end
      else
        return @custom_health_check.call
      end

      true
    end

    def all_instances_inservice_for_time_period?
      if all_instances_inservice?
        if @time_spent_inservice >= @opts[:min_inservice_time]
          return true
        else
          logger.info "All instances have been InService for #{@time_spent_inservice} seconds."

          @time_spent_inservice += INSERVICE_POLLING_TIME
          return false
        end
      else
        @time_spent_inservice = 0
        return false
      end
    end

    private

    def using_elb?
      @custom_health_check.nil?
    end
  end
end
