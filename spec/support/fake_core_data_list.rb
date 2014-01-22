module AWS
  module FakeCore
    class Data
      module MethodMissingProxy

        protected

        def method_missing *args, &block
          if block_given?
            return_value = @data.send(*args) do |*values|
              yield(*values.flatten.map{|v| Data.cast(v) })
            end
            Data.cast(return_value)
          else
            Data.cast(@data.send(*args))
          end
        end

      end

      include MethodMissingProxy

      def method_missing method_name, *args, &block
        if
          args.empty? and !block_given? and
          key = _remove_question_mark(method_name) and
          @data.has_key?(key)
        then
          Data.cast(@data[key])
        else
          super
        end
      end

      class << self

        # Given a hash, this method returns a {Data} object.  Given
        # an Array, this method returns a {Data::List} object.  Everything
        # else is returned as is.
        #
        # @param [Object] value The value to conditionally wrap.
        #
        # @return [Data,Data::List,Object] Wraps hashes and lists with
        #   Data and List objects, all other objects are returned as
        #   is.
        #
        def cast value
          case value
          when Hash then Data.new(value)
          when Array then Data::List.new(value)
          else value
          end
        end

      end

      class List
        include MethodMissingProxy

        def initialize(array)
          @data = array
        end

        def to_ary
          @data
        end
        alias_method :to_a, :to_ary
      end
    end
  end
end
