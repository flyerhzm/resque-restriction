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
        keys_decremented = []
        settings.each do |period, number|
          key = redis_key(period, *args)

          # first try to set period key to be the total allowed for the period
          # if we get a 0 result back, the key wasn't set, so we know we are
          # already tracking the count for that period'
          period_active = ! Resque.redis.setnx(key, number.to_i - 1)

          # If we are already tracking that period, then decrement by one to
          # see if we are allowed to run, pushing to restriction queue to run
          # later if not
          if period_active
            value = Resque.redis.decrby(key, 1).to_i
            if value < 0
              # reincrement the keys if one of the periods triggers DontPerform so
              # that we accurately track capacity
              keys_decremented.each {|k| Resque.redis.incrby(k, 1) }
              Resque.push "restriction", :class => to_s, :args => args
              raise Resque::Job::DontPerform
            else
              keys_decremented << key
            end
          end
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
          value = Resque.redis.get(key)
          no_restrictions &&= (value.nil? or value == "" or value.to_i >= 0)
        end
        if no_restrictions
          Resque.push queue_name, :class => to_s, :args => args
        else
          Resque.push "restriction", :class => to_s, :args => args
        end
      end

    end

    class RestrictionJob
      extend Restriction
    end

  end
end
