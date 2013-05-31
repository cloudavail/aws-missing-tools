class AwsHaRelease
  def initialize(opts)
    AWS.config(access_key_id: opts[:aws_access_key], secret_access_key: opts[:aws_secret_key], region: opts[:region])

    @as = AWS::AutoScaling.new
    @group = @as.groups[opts[:as_group_name]]

    if @group.nil?
      raise ArgumentError, "The Auto Scaling Group named #{opts[:as_group_name]} does not exist in #{opts[:region]}."
    end
  end

  def execute!
    @group.suspend_processes 'ReplaceUnhealthy', 'AlarmNotification', 'ScheduledActions', 'AZRebalance'
  end
end
