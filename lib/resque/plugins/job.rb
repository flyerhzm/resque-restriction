module Resque
  class Job
    class <<self
      alias_method :origin_reserve, :reserve

      def reserve(queue)
        return unless payload = Resque.peek(queue)
        job_class = Object.const_get(payload['class'])

        # hold if it reaches restriction.
        return if job_class.respond_to?(:restriction_settings) && !job_class.restriction_settings.empty? && job_class.reach_restriction?(*payload['args']) == true
        job_class.reset_concurrent_restriction(*payload['args'])

        origin_reserve(queue)
      end
    end
  end
end
