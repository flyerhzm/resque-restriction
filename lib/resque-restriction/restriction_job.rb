module Resque
  module Plugins
    class RestrictionJob
      SECONDS = {
        :per_minute => 60,
        :per_hour => 60*60,
        :per_day => 24*60*60,
        :per_month => 31*24*60*60,
        :per_year => 366*24*60*60
      }

      class <<self
        def settings
          @options ||= {}
        end

        def restrict(options={})
          settings.merge!(options)
        end
        
        def before_perform_restriction(*args)
          settings.each do |period, number|
            key = redis_key(period)
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
            key = redis_key(period)
            Resque.redis.decrby(key, 1)
          end
        end

        def redis_key(period)
          period_str = case period
                       when :per_minute, :per_hour, :per_day then (Time.now.to_i / SECONDS[period]).to_s
                       when :per_month then Date.today.strftime("%Y-%m")
                       when :per_year then Date.today.year.to_s
                       else period.to_s =~ /^per_(\d+)$/ and (Time.now.to_i / $1.to_i).to_s end
          [self.to_s, period_str].compact.join(":")
        end

        def seconds(period)
          if SECONDS.keys.include? period
            SECONDS[period]
          else
            period.to_s =~ /^per_(\d+)$/ and $1
          end
        end

        def repush
          settings.each do |period, number|
            key = redis_key(period)
            value = get_restrict(key)
            if value.nil? or value == ""
              Resque.redis.rpoplpush('queue:restriction', "queue:#{queue}")
            end
          end
        end

        private
          # after operation incrby - expire, then decrby will reset the value to 0 first
          # use operation set - expire - incrby instead
          def set_restrict(key, seconds, number)
            Resque.redis.set(key, '')
            Resque.redis.expire(key, seconds)
            Resque.redis.incrby(key, number)
          end

          def get_restrict(key)
            Resque.redis.get(key)
          end
      end
    end
  end
end
