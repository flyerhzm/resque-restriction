require 'rubygems'
require 'spec/autorun'
require 'mocha'

dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require 'resque-restriction'

#
# make sure we can run redis
#

if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end


#
# start our own redis when the tests start,
# kill it when they end
#

at_exit do
  next if $!

  exit_code = Spec::Runner.run

  pid = `ps -e -o pid,command | grep [r]edis-test`.split(" ")[0]
  puts "Killing test redis server..."
  `rm -f #{dir}/dump.rdb`
  Process.kill("KILL", pid.to_i)
  exit exit_code
end

puts "Starting redis for testing at localhost:9736..."
`redis-server #{dir}/redis-test.conf`
Resque.redis = 'localhost:9736'

##
# Helper to perform job classes
#
module PerformJob
  def perform_job(klass, *args)
    resque_job = Resque::Job.new(:testqueue, 'class' => klass, 'args' => args)
    resque_job.perform
  end
end

class OneDayRestrictionJob < Resque::Plugins::RestrictionJob
  restrict :per_day => 100

  @queue = 'normal'
  
  def self.perform(args)
  end
end

class OneHourRestrictionJob < Resque::Plugins::RestrictionJob
  restrict :per_hour => 10

  @queue = 'normal'

  def self.perform(args)
  end
end

class MultipleRestrictionJob < Resque::Plugins::RestrictionJob
  restrict :per_hour => 10, :per_300 => 2

  @queue = 'normal'

  def self.perform(args)
  end
end

class MultiCallRestrictionJob < Resque::Plugins::RestrictionJob
  restrict :per_hour => 10
  restrict :per_300 => 2

  @queue = 'normal'

  def self.perform(args)
  end
end
