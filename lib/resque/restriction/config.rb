module Resque
  module Restriction
    def self.configure
      yield config
    end

    def self.config
      @config ||= Config.new
    end

    class Config
      def initialize
        @max_queue_peek = nil
      end

      def max_queue_peek=(value_or_callable)
        if value_or_callable.respond_to?(:call)
          @max_queue_peek = value_or_callable
        elsif value_or_callable.nil?
          @max_queue_peek = nil
        else
          @max_queue_peek = validated_max_queue_peek(value_or_callable)
        end
      end

      def max_queue_peek(queue)
        @max_queue_peek.respond_to?(:call) ? @max_queue_peek.call(queue) : @max_queue_peek
      end

      private

      def validated_max_queue_peek(value)
        peek = nil

        begin
          peek = Integer(value)

          if peek <= 0
            raise ArgumentError
          end
        rescue ArgumentError
          raise ArgumentError,
                "max_queue_peek should be either nil or an Integer greater than 0 but #{value.inspect} was provided"
        end

        peek
      end
    end
  end
end
