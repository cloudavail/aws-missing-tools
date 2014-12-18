require 'optparse'

module AwsMissingTools
  class AwsHaRelease
    def initialize(argv)
      @argv = argv
    end

    def parse_options(argv)
      options = {}

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
      end.parse!(argv)

      options
    end

    def validate_options(_options)
      raise OptionParser::MissingArgument, 'You must specify the AutoScaling Group Name.' if _options[:as_group_name].nil?

      options = {
        region: 'us-east-1',
        elb_timeout: 60,
        inservice_time_allowed: 300,
        min_inservice_time: 30,
        num_simultaneous_instances: 1,
        log_output: "log/#{_options[:as_group_name]}_cycling.log",
        log_level: Logger::WARN
      }.merge(_options)

      if options[:aws_secret_key] && options[:aws_access_key].nil? || options[:aws_access_key] && options[:aws_secret_key].nil?
        raise OptionParser::MissingArgument, 'If specifying either the AWS Access or Secret Key, then the other must also be specified.'
      elsif options[:aws_secret_key].nil? && options[:aws_access_key].nil?
        options[:aws_access_key] = ENV['AWS_ACCESS_KEY']
        options[:aws_secret_key] = ENV['AWS_SECRET_KEY']
      end

      options
    end

    def execute!
      options = validate_options(parse_options(@argv))
      CycleServers.new(options).cycle
    end
  end
end
