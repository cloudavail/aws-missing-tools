require 'optparse'

module AwsMissingTools
  class AwsHaRelease
    def initialize(argv)
      @opts = AwsHaRelease.parse_options(argv)
      @opts[:num_simultaneous_instances] = Integer(@opts[:num_simultaneous_instances]) rescue @group.auto_scaling_instances.count
    end

    def self.parse_options(arguments)
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
          options[:num_simultaneous_instances] = v
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
      CycleServers.new(@opts).cycle
    end
  end
end
