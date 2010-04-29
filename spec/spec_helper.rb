require 'rubygems'
require 'spec/autorun'
require 'mocha'

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require 'resque-restriction'


class OneDayRestrictionJob < Resque::Plugins::RestrictionJob
  @queue = :some_queue
  restrict :per_day => 1000
  
  def self.perform(some_id, some_other_thing)
  end
end

class OneHourRestrictionJob < Resque::Plugins::RestrictionJob
  @queue = :some_queue
  restrict :per_hour => 100

  def self.perform(some_id, some_other_thing)
  end
end

class OneMinuteRestrictionJob < Resque::Plugins::RestrictionJob
  @queue = :some_queue
  restrict :per_minute => 10

  def self.perform(some_id, some_other_thing)
  end
end
