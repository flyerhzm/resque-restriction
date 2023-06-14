require File.expand_path('../spec_helper', File.dirname(__FILE__))

RSpec.describe Resque::Job do
  before(:example) do
    Resque.redis.redis.flushall
  end

  it "should repush restriction queue when reserve" do
    Resque.push('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
    expect(Resque::Job.reserve('restriction_normal')).to eq Resque::Job.new(
      'restriction_normal',
      {
        'class' => 'OneHourRestrictionJob',
        'args' => ['any args']
      }
    )
    expect(Resque::Job.reserve('restriction_normal')).to be_nil
    expect(Resque::Job.reserve('normal')).to be_nil
  end

  it "should push back to restriction queue when still restricted" do
    Resque.redis.set(OneHourRestrictionJob.resque_restriction_redis_key(:per_hour), -1)
    Resque.push('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
    expect(Resque::Job.reserve('restriction_normal')).to be_nil
    expect(Resque.pop('restriction_normal')).to eq({ 'class' => 'OneHourRestrictionJob', 'args' => ['any args'] })
    expect(Resque::Job.reserve('normal')).to be_nil
  end

  it "should not repush when reserve normal queue" do
    Resque.push('normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
    expect(Resque::Job.reserve('normal')).to eq Resque::Job.new(
      'normal',
      {
        'class' => 'OneHourRestrictionJob',
        'args' => ['any args']
      }
    )
    expect(Resque::Job.reserve('normal')).to be_nil
    expect(Resque::Job.reserve('restriction_normal')).to be_nil
  end

  it "should only push back queue_length times to restriction queue" do
    Resque.redis.set(OneHourRestrictionJob.resque_restriction_redis_key(:per_hour), -1)
    3.times { Resque.push('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args']) }
    expect(Resque.size('restriction_normal')).to eq 3
    expect(OneHourRestrictionJob).to receive(:repush).exactly(3).times.and_return(true)
    Resque::Job.reserve('restriction_normal')
  end
end
