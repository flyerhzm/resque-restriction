module Resque
  module Plugins
    class RestrictionJob
      ONE_DAY = 60*60*24
      
      RESCRICTION_SETTINGS = {
        :number => 1000,
        :period => ONE_DAY
      }

      def self.settings
        @settings ||= RESCRICTION_SETTINGS.dup
      end
      
      def self.restrict(options = {})
        settings.merge!(options)
      end

      def self.key(*args)
        [self.to_s, Date.today].compact.join(":")
      end

      def self.number
        settings[:number]
      end
      
      def self.period
        settings[:period]
      end
      
      def self.before_perform_restriction(*args)
        if should_restrict?(*args)
          raise Resque::Job::DontPerform
        end
      end
      
      def self.after_perform_restriction(*args)
        Resque.redis.decrby(self.key(*args), 1)
      end
      

      private
      def self.should_restrict?(*args)
        key = self.key(*args)
        num = Resque.redis.get(key)
        
        if num.nil?
          # after operation incrby - expire, then decrby will reset the value to 0 first
          # use operation set - expire - incrby instead
          Resque.redis.set(key, '')
          Resque.redis.expire(key, period)
          Resque.redis.incrby(key, number)
          Resque.redis.rpoplpush('queue:restriction', "queue:#{queue}")
          return false
        elsif num.to_i > 0
          return false
        else
          Resque.push "restriction", :class => self.to_s, :args => args
          return true
        end
      end
    end
  end
end