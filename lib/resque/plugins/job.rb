module Resque
  class Job
    class <<self
      alias_method :origin_reserve, :reserve

      def reserve(queue)
        return unless payload = Resque.peek(queue)
        job_class = Object.const_get(payload['class'])

        if queue =~ /^#{Plugins::Restriction::RESTRICTION_QUEUE_PREFIX}/
          # hold if it is a restriction queue and reaches restriction.
          return if job_class.reach_restriction?(payload)
        else
          if job_class.respond_to?(:restriction_queue_name)
            # if it is a normal queue and extends restriction plugin,
            # pop and push to restriction queue.
            Resque.pop(queue)
            Resque.push(job_class.restriction_queue_name, :class => payload['class'], :args => payload['args'])
            return
          end
        end

        origin_reserve(queue)
      end
    end
  end
end
