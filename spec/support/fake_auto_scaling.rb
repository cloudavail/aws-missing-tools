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
        @suspended_processes = {}
      end

      def suspend_processes(*processes)
        processes.each do |process|
          @suspended_processes[process] = 'test'
        end
      end
    end
  end
end
