module Resque
  module Plugins
    module Restriction
      SECONDS = {
        :per_minute => 60,
        :per_hour => 60*60,
        :per_day => 24*60*60,
        :per_week => 7*24*60*60,
        :per_month => 31*24*60*60,
        :per_year => 366*24*60*60
      }
      RESTRICTION_QUEUE_PREFIX = 'restriction'

      def settings
        @options ||= {}
      end

      def restrict(options={})
        settings.merge!(options)
      end

      def before_perform_restriction(*args)
        keys_decremented = []
        settings.each do |period, number|
          key = redis_key(period, *args)

          # first try to set period key to be the total allowed for the period
          # if we get a 0 result back, the key wasn't set, so we know we are
          # already tracking the count for that period'
          period_active = ! Resque.redis.setnx(key, number.to_i - 1)

          # If we are already tracking that period, then decrement by one to
          # see if we are allowed to run, pushing to restriction queue to run
          # later if not.  Note that the value stored is the number of outstanding
          # jobs allowed, thus we need to reincrement if the decr discovers that
          # we have bypassed the limit
          if period_active
            value = Resque.redis.decrby(key, 1).to_i
            keys_decremented << key
            if value < 0
              # reincrement the keys if one of the periods triggers DontPerform so
              # that we accurately track capacity
              keys_decremented.each {|k| Resque.redis.incrby(k, 1) }
              Resque.push restriction_queue_name, :class => to_s, :args => args
              raise Resque::Job::DontPerform
            end
          end
        end
      end

      def after_perform_restriction(*args)
        if settings[:concurrent]
          key = redis_key(:concurrent, *args)
          Resque.redis.incrby(key, 1)
        end
      end

      def on_failure_restriction(ex, *args)
        after_perform_restriction(*args)
      end

      def redis_key(period, *args)
        period_str = case period
                     when :concurrent then "*"
                     when :per_minute, :per_hour, :per_day, :per_week then (Time.now.to_i / SECONDS[period]).to_s
                     when :per_month then Date.today.strftime("%Y-%m")
                     when :per_year then Date.today.year.to_s
                     else period.to_s =~ /^per_(\d+)$/ and (Time.now.to_i / $1.to_i).to_s end
        [self.identifier(*args), period_str].compact.join(":")
      end

      def identifier(*args)
        self.to_s
      end

      def restriction_queue_name
        queue_name = Resque.queue_from_class(self)
        "#{RESTRICTION_QUEUE_PREFIX}_#{queue_name}"
      end

      def seconds(period)
        if SECONDS.keys.include? period
          SECONDS[period]
        else
          period.to_s =~ /^per_(\d+)$/ and $1
        end
      end

      # if job is still restricted, push back to restriction queue, otherwise push
      # to real queue.  Since the restrictions will be checked again when run from
      # real queue, job will just get pushed back onto restriction queue then if
      # restriction conditions have changed
      def repush(*args)
        no_restrictions = true
        settings.each do |period, number|
          key = redis_key(period, *args)
          value = Resque.redis.get(key)
          no_restrictions &&= (value.nil? or value == "" or value.to_i > 0)
          break unless no_restrictions
        end
        if no_restrictions
          Resque.push Resque.queue_from_class(self), :class => to_s, :args => args
        else
          Resque.push restriction_queue_name, :class => to_s, :args => args
        end
      end

    end

    class RestrictionJob
      extend Restriction
    end

  end
end
