module AWS
  class FakeEC2
    def initialize
    end

    class Instance
      def initialize
      end

      def terminate(decrement_desired_capacity)
      end

      def id
        'i-test'
      end
    end
  end
end
