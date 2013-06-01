module AWS
  class FakeELB
    def initialize
    end

    class LoadBalancer
      def initialize(name, options = {})
      end

      def instances
        @instances ||= InstanceCollection.new
      end
    end

    class InstanceCollection
      def initialize
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
