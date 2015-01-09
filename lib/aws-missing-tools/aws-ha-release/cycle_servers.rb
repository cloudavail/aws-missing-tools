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

      AWS.config(access_key_id: @opts[:aws_access_key], secret_access_key: @opts[:aws_secret_key], region: @opts[:region], max_retries: 20)
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
      processes = @group.suspended_processes.keys & %w(RemoveFromLoadBalancerLowPriority Terminate Launch HealthCheck AddToLoadBalancer)
      raise "AutoScaling process(es) #{processes.join(', ')} is/are currently suspended on #{group_name} but is/are necessary for this script." if processes.any?

      @group.suspend_processes PROCESSES_TO_SUSPEND

      attributes = {}
      if max_size_change > 0
        logger.warn "#{group_name} has a max-size of #{@max_size}. In order to recycle instances max-size will be temporarily increased by #{max_size_change}."
        @max_size += max_size_change
        attributes.merge!(max_size: @max_size)
      end

      @desired_capacity += @opts[:num_simultaneous_instances]
      attributes.merge!(desired_capacity: @desired_capacity)
      @group.update(attributes)

      auto_scaling_instances = @group.auto_scaling_instances
      logger.info "The list of instances in Auto Scaling Group #{group_name} that will be terminated is:#{auto_scaling_instances.map{ |i| i.ec2_instance.id }.to_ary}"
      logger.info "The number of instances that will be brought up simultaneously is: #{@opts[:num_simultaneous_instances]}"

      auto_scaling_instances.to_a.each_slice(@opts[:num_simultaneous_instances]) do |instances|
        time_taken = 0

        until all_instances_inservice_for_time_period?
          logger.info "#{time_taken} seconds have elapsed while waiting for all instances to be InService for a minimum of #{@opts[:min_inservice_time]} seconds."

          if time_taken >= @opts[:inservice_time_allowed]
            logger.warn "During the last #{time_taken} seconds, a new AutoScaling instance failed to become healthy."
            logger.warn "The following settings were changed and will not be changed back by this script:"

            logger.warn "AutoScaling processes #{PROCESSES_TO_SUSPEND} were suspended."
            logger.warn "The desired capacity was changed from #{@desired_capacity - @opts[:num_simultaneous_instances]} to #{@desired_capacity}."

            logger.warn "The maximum size was changed from #{@max_size - max_size_change} to #{@max_size}" if max_size_change > 0

            raise
          else
            time_taken += INSERVICE_POLLING_TIME
            sleep INSERVICE_POLLING_TIME
          end
        end

        logger.info 'The new instance(s) was/were found to be healthy.'

        if using_elb?
          logger.info "#{@opts[:num_simultaneous_instances]} old instance(s) will now be removed from the load balancers."
          instances.each { |instance| deregister_instance(instance.ec2_instance, load_balancers) }

          logger.info "Sleeping for the ELB Timeout period of #{@opts[:elb_timeout]}"
          sleep @opts[:elb_timeout]
        end

        logger.info "Instance(s) #{instances.map{ |i| i.ec2_instance.id }.join(', ')} will now be terminated. By terminating this/these instance(s), the actual capacity will be decreased to #{@opts[:num_simultaneous_instances]} under desired-capacity."
        instances.each { |instance| instance.terminate false }
      end

      logger.info "#{group_name} had its desired-capacity increased temporarily by #{@opts[:num_simultaneous_instances]} to a desired-capacity of #{@desired_capacity}."
      logger.info "The desired-capacity of #{group_name} will now be returned to its original desired-capacity of #{@desired_capacity - @opts[:num_simultaneous_instances]}."

      @desired_capacity -= @opts[:num_simultaneous_instances]
      attributes = {
        desired_capacity: @desired_capacity
      }

      if max_size_change > 0
        logger.warn "#{group_name} had its max_size increased temporarily by #{max_size_change} to a max_size of #{@max_size}."
        logger.warn "The max_size of #{group_name} will now be returned to its original max_size of #{@max_size - max_size_change}."

        @max_size -= max_size_change
        attributes.merge!(max_size: @max_size)
      end

      @group.update(attributes)
      @group.resume_all_processes
    end

    def max_size_change
      # okay to memoize even though there are instances variables inside because once this method is called, we never want the value to change
      @max_size_change ||= begin
        @desired_capacity = @group.desired_capacity
        @max_size = @group.max_size

        if @max_size - @desired_capacity < @opts[:num_simultaneous_instances]
          @desired_capacity + @opts[:num_simultaneous_instances] - @max_size
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
      return false if load_balancer.instances.count != @desired_capacity

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
        load_balancers.each do |load_balancer|
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

    def group_name
      @group_name ||= @group.name
    end

    def load_balancers
      @load_balancers ||= @group.load_balancers
    end

    def using_elb?
      @custom_health_check.nil?
    end
  end
end
