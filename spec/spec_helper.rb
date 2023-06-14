require 'bundler/setup'
require 'resque/restriction'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

#
# make sure we can run redis
#

if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end

dir = File.dirname(__FILE__)

#
# start our own redis when the tests start,
# kill it when they end
#

at_exit do
  status_code =
    if $!.nil? || $!.is_a?(SystemExit) && $!.success?
      0
    else
      $!.is_a?(SystemExit) ? $!.status : 1
    end

  pid = `ps -e -o pid,command | grep [r]edis-test`.split(" ")[0]
  puts "Killing test redis server [#{pid}]..."
  `rm -f #{dir}/dump.rdb`
  exit status_code
end

puts "Starting redis for testing at localhost:9736..."
`redis-server #{dir}/redis-test.conf`
Resque.redis = 'localhost:9736'

#
# Helper to perform job classes
#
module PerformJob
  def perform_job(klass, *args)
    resque_job = Resque::Job.new(:testqueue, 'class' => klass, 'args' => args)
    resque_job.perform
  end
end

class MyJob
  extend Resque::Plugins::Restriction

  @queue = 'awesome_queue_name'
end

class OneDayRestrictionJob
  extend Resque::Plugins::Restriction

  restrict :per_day => 100

  @queue = 'normal'

  def self.perform(*args)
  end
end

class OneHourRestrictionJob
  extend Resque::Plugins::Restriction

  restrict :per_hour => 10

  @queue = 'normal'

  def self.perform(*args)
  end
end

class IdentifiedRestrictionJob
  extend Resque::Plugins::Restriction

  restrict :per_hour => 10

  @queue = 'normal'

  def self.restriction_identifier(*args)
    [self.to_s, args.first].join(":")
  end

  def self.perform(*args)
  end
end

class ConcurrentRestrictionJob
  extend Resque::Plugins::Restriction

  restrict :concurrent => 1

  @queue = 'normal'

  def self.perform(*args)
    sleep 0.2
  end
end

class MultipleRestrictionJob
  extend Resque::Plugins::Restriction

  restrict :per_hour => 10, :per_300 => 2

  @queue = 'normal'

  def self.perform(*args)
  end
end

class MultiCallRestrictionJob
  extend Resque::Plugins::Restriction

  restrict :per_hour => 10
  restrict :per_300 => 2

  @queue = 'normal'

  def self.perform(*args)
  end
end
