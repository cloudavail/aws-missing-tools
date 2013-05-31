class AwsHaRelease
  attr_reader :max_size_change

  def initialize(opts)
    AWS.config(access_key_id: opts[:aws_access_key], secret_access_key: opts[:aws_secret_key], region: opts[:region])

    @as = AWS::AutoScaling.new
    @group = @as.groups[opts[:as_group_name]]

    if @group.nil?
      raise ArgumentError, "The Auto Scaling Group named #{opts[:as_group_name]} does not exist in #{opts[:region]}."
    end

    @max_size_change = 0
  end

  def execute!
    @group.suspend_processes 'ReplaceUnhealthy', 'AlarmNotification', 'ScheduledActions', 'AZRebalance'

    if @group.max_size == @group.desired_capacity
      @group.update(max_size: @group.max_size + 1)
      @max_size_change += 1
    end

    @group.update(desired_capacity: @group.desired_capacity + 1)
  end
end
