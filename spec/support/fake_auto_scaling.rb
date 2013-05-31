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
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end
  end
end
