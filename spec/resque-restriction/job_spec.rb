require File.join(File.dirname(__FILE__) + '/../spec_helper')

describe Resque::Job do
  before(:each) do
    Resque.redis.flushall
  end

  it "should repush restriction queue when reserve" do
    Resque.push('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
    Resque::Job.reserve('restriction_normal').should == Resque::Job.new('restriction_normal', {'class' => 'OneHourRestrictionJob', 'args' => ['any args']})
    Resque::Job.reserve('restriction_normal').should be_nil
    Resque::Job.reserve('normal').should be_nil
  end

  it "should push back to restriction queue when still restricted" do
    Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), -1)
    Resque.push('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
    Resque::Job.reserve('restriction_normal').should be_nil
    Resque.pop('restriction_normal').should == {'class' => 'OneHourRestrictionJob', 'args' => ['any args']}
    Resque::Job.reserve('normal').should be_nil
  end

  it "should not repush when reserve normal queue" do
    Resque.push('normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
    Resque::Job.reserve('normal').should == Resque::Job.new('normal', {'class' => 'OneHourRestrictionJob', 'args' => ['any args']})
    Resque::Job.reserve('normal').should be_nil
    Resque::Job.reserve('restriction_normal').should be_nil
  end

  it "should only push back queue_length times to restriction queue" do
    Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), -1)
    3.times { Resque.push('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args']) }
    Resque.size('restriction_normal').should == 3
    OneHourRestrictionJob.should_receive(:repush).exactly(3).times.and_return(true)
    Resque::Job.reserve('restriction_normal')
  end


end
