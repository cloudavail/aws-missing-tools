module AWS
  class FakeEC2
    class Instance
      attr_reader :id

      def initialize(id)
        @id = id
      end
    end
  end
end
