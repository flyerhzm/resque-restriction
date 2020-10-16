module Resque
  module Restriction
    def self.configure
      yield config
    end

    def self.config
      @config ||= Config.new
    end

    class Config
      attr_writer :max_queue_peek

      def initialize
        @max_queue_peek = 100
      end

      def max_queue_peek(queue)
        @max_queue_peek.respond_to?(:call) ? @max_queue_peek.call(queue) : @max_queue_peek
      end
    end
  end
end
