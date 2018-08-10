module Resque
  class Job
    class <<self
      alias_method :origin_reserve, :reserve

      def reserve(queue)
        return unless payload = Resque.peek(queue)
        job_class = Object.const_get(payload['class'])

        if job_class.is_a?(Resque::Plugins::Restriction)
          return if !job_class.restriction_settings.empty? && job_class.reach_restriction?(*payload['args'])
          job_class.reset_concurrent_restriction(*payload['args'])
        end
        origin_reserve(queue)
      end
    end
  end
end
