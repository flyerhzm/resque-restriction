require File.join(File.dirname(__FILE__) + '/../spec_helper')

describe Resque::Job do
  it "should repush restrictioin queue when reserve" do
    Resque.redis.flushall
    Resque.push('restriction', :class => 'OneHourRestrictionJob', :args => 'any args')
    Resque::Job.reserve('restriction').should be_nil
    Resque::Job.reserve('normal').should == Resque::Job.new('normal', {'class' => 'OneHourRestrictionJob', 'args' => 'any args'})
    Resque::Job.reserve('normal').should be_nil
  end

  it "should not repush when reserve normal queue" do
    Resque.push('normal', :class => 'OneHourRestrictionJob', :args => 'any args')
    Resque::Job.reserve('normal').should == Resque::Job.new('normal', {'class' => 'OneHourRestrictionJob', 'args' => 'any args'})
    Resque::Job.reserve('normal').should be_nil
  end
end
