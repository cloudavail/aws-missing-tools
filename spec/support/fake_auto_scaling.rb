module AWS
  class FakeAutoScaling
    def initialize
    end

    def groups
      @groups ||= GroupCollection.new
    end

    class GroupCollection
      def initialize
        @groups = {}
      end

      def [](name)
        @groups[name]
      end

      def create(name, options = {})
        @groups[name] = Group.new name
      end
    end

    class Group
      attr_reader :name, :max_size, :desired_capacity, :suspended_processes

      def initialize(name)
        @name = name
        @suspended_processes = {}
        @max_size = 2
        @desired_capacity = 1
      end

      def suspend_processes(processes)
        processes.each do |process|
          @suspended_processes[process] = 'test'
        end
      end

      def resume_all_processes
        @suspended_processes.clear
      end

      def update(options = {})
        options.each do |key, value|
          self.instance_variable_set "@#{key}", value
        end
      end

      def auto_scaling_instances
        @auto_scaling_instances ||= AWS::FakeCore::Data::List.new [AWS::FakeAutoScaling::Instance.new(self), AWS::FakeAutoScaling::Instance.new(self)]
      end

      def load_balancers
        @load_balancers ||= AWS::FakeELB::LoadBalancerCollection.new
      end

      def ec2_instances
        auto_scaling_instances.map(&:ec2_instance)
      end
    end

    class Instance
      def initialize(group)
        @group = group
      end

      def terminate(decrement_desired_capacity)
        @group.update(desired_capacity: @group.desired_capacity - 1) if decrement_desired_capacity
      end

      def id
        'i-test'
      end

      def ec2_instance
        AWS::FakeEC2::Instance.new(self.id)
      end
    end
  end
end
