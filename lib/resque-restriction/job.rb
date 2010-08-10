module Resque
  class Job
    class <<self
      alias_method :origin_reserve, :reserve
      
      def reserve(queue)
        if queue =~ /^#{Plugins::Restriction::RESTRICTION_QUEUE_PREFIX}/ && payload = Resque.pop(queue)
          constantize(payload['class']).repush(*payload['args'])
          return
        end
        origin_reserve(queue)
      end
    end
  end
end
