require 'rubygems'
require 'spec/autorun'
require 'mocha'

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require 'resque-restriction'


class DefaultRestrictionJob < Resque::Plugins::RestrictionJob
  @queue = :some_queue
  
  def self.perform(some_id, some_other_thing)
  end
end

class OneHourRestrictionJob < Resque::Plugins::RestrictionJob
  @queue = :some_queue
  restrict :period => 3600

  def self.perform(some_id, some_other_thing)
  end
end

class TenNumberRestrictionJob < Resque::Plugins::RestrictionJob
  @queue = :some_queue
  restrict :number => 10

  def self.perform(some_id, some_other_thing)
  end
end