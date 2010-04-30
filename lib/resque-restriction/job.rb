module Resque
  class Job
    class <<self
      alias_method :origin_reserve, :reserve
      
      def reserve(queue)
        if queue == 'restriction' && payload = Resque.peek(queue)
          constantize(payload['class']).repush
          return
        end
        origin_reserve(queue)
      end
    end
  end
end
