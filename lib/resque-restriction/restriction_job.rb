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

      def settings
        @options ||= {}
      end

      def restrict(options={})
        settings.merge!(options)
      end

      def before_perform_restriction(*args)
        settings.each do |period, number|
          key = redis_key(period, *args)
          value = get_restrict(key)

          if value.nil? or value == ""
            set_restrict(key, seconds(period), number)
          elsif value.to_i <= 0
            Resque.push "restriction", :class => to_s, :args => args
            raise Resque::Job::DontPerform
          end
        end
      end

      def after_perform_restriction(*args)
        settings.each do |period, number|
          key = redis_key(period, *args)
          Resque.redis.decrby(key, 1)
        end
      end

      def redis_key(period, *args)
        period_str = case period
                     when :per_minute, :per_hour, :per_day, :per_week then (Time.now.to_i / SECONDS[period]).to_s
                     when :per_month then Date.today.strftime("%Y-%m")
                     when :per_year then Date.today.year.to_s
                     else period.to_s =~ /^per_(\d+)$/ and (Time.now.to_i / $1.to_i).to_s end
        [self.identifier(*args), period_str].compact.join(":")
      end

      def identifier(*args)
        self.to_s
      end

      def seconds(period)
        if SECONDS.keys.include? period
          SECONDS[period]
        else
          period.to_s =~ /^per_(\d+)$/ and $1
        end
      end

      def repush(*args)
        no_restrictions = true
        queue_name = Resque.queue_from_class(self)
        settings.each do |period, number|
          key = redis_key(period, *args)
          value = get_restrict(key)
          no_restrictions &&= (value.nil? or value == "" or value.to_i > 0)
        end
        if no_restrictions
          Resque.push queue_name, :class => to_s, :args => args
        else
          Resque.push "restriction", :class => to_s, :args => args
        end
      end

      private
        # after operation incrby - expire, then decrby will reset the value to 0 first
        # use operation set - expire - incrby instead
        def set_restrict(key, seconds, number)
          Resque.redis.set(key, '')
          Resque.redis.incrby(key, number)
        end

        def get_restrict(key)
          Resque.redis.get(key)
        end
    end

    class RestrictionJob
      extend Restriction
    end

  end
end
