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
        def restrict(options={})
          @options = options
        end

        def redis_key(period)
          period_str = case period
                       when :per_minute then Time.now.strftime("%Y-%m-%d %H:%M")
                       when :per_hour then Time.now.strftime("%Y-%m-%d %H")
                       when :per_day then Date.today.to_s
                       when :per_month then Date.today.strftime("%Y-%m")
                       when :per_year then Date.today.year.to_s
                       end
          [self.to_s, period_str].compact.join(":")
        end
        
        def before_perform_restriction(*args)
          @options.each do |period, number|
            key = redis_key(period)
            value = Resque.redis.get(key)

            if value.nil? 
              # after operation incrby - expire, then decrby will reset the value to 0 first
              # use operation set - expire - incrby instead
              Resque.redis.set(key, '')
              Resque.redis.expire(key, period)
              Resque.redis.incrby(key, SECONDS[period])
              Resque.redis.rpoplpush('queue:restriction', "queue:#{queue}")
            else value.to_i <= 0
              Resque.push "restriction", :class => to_s, :args => args
              raise Resque::Job::DontPerform
            end
          end
        end
        
        def after_perform_restriction(*args)
          @options.each do |period, number|
            key = redis_key(period)
            Resque.redis.decrby(key, 1)
          end
        end
      end
    end
  end
end
