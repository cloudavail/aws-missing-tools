module AWS
  class FakeELB
    def initialize
    end

    class LoadBalancer
      attr_reader :name

      def initialize(name, options = {})
        @name = name
      end

      def instances
        @instances ||= InstanceCollection.new
      end
    end

    class LoadBalancerCollection < Array
      def initialize
      end
    end

    class InstanceCollection < Array
      def initialize
      end

      def register(*instances)
        self.concat instances
      end

      def deregister(*instances)
        instances.each do |i|
          self.delete i
        end
      end

      def health
        @health ||= [
          {
            instance: AWS::FakeEC2::Instance.new,
            description: 'N/A',
            state: 'InService',
            reason_code: 'N/A'
          },
          {
            instance: AWS::FakeEC2::Instance.new,
            description: 'Instance has failed at least the UnhealthyThreshold number of health checks consecutively.',
            state: 'OutOfService',
            reason_code: 'Instance'
          }
        ]
      end
    end
  end
end
