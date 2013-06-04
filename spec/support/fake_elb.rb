module AWS
  class FakeELB
    def initialize
    end

    class LoadBalancer
      attr_reader :name, :instances

      def initialize(name, instances_and_healths)
        @name = name
        @instances ||= InstanceCollection.new(instances_and_healths)
      end
    end

    class LoadBalancerCollection < Array
      def initialize
      end
    end

    class InstanceCollection < Array
      attr_reader :health

      def initialize(instances_and_healths)
        @health = []

        instances_and_healths.each do |instance_and_health|
          self << instance_and_health[:instance]
          instance_and_health[:healthy] ? make_instance_healthy(instance_and_health[:instance]) : make_instance_unhealthy(instance_and_health[:instance])
        end
      end

      def register(*instances)
        self.concat instances
      end

      def deregister(*instances)
        instances.each do |i|
          self.delete i
        end
      end

      def make_instance_healthy(instance)
        opts = {
          instance: instance,
          description: 'N/A',
          state: 'InService',
          reason_code: 'N/A'
        }

        @health.each_with_index do |health, i|
          if health[:instance] == instance
            @health[i] = opts
            return
          end
        end

        @health << opts
      end

      def make_instance_unhealthy(instance)
        opts = {
          instance: instance,
          description: 'Instance has failed at least the UnhealthyThreshold number of health checks consecutively.',
          state: 'OutOfService',
          reason_code: 'Instance'
        }

        @health.each_with_index do |health, i|
          if health[:instance] == instance
            @health[i] = opts
            return
          end
        end

        @health << opts
      end
    end
  end
end
