require 'spec_helper'

RSpec.describe Resque::Job do
  before(:example) do
    Resque.redis.flushall
  end

  context 'reserve restriction queue' do
    context 'reach restriction' do
      it "should do nothing" do
        Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), -1)
        Resque.push('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
        expect(Resque::Job.reserve('restriction_normal')).to be_nil
        expect(Resque.pop('restriction_normal')).to eq({'class' => 'OneHourRestrictionJob', 'args' => ['any args']})
        expect(Resque.pop('normal')).to be_nil
      end
    end

    context 'do not reach restriction' do
      it "should pop job" do
        Resque.push('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
        expect(Resque::Job.reserve('restriction_normal')).to eq Resque::Job.new('restriction_normal', {'class' => 'OneHourRestrictionJob', 'args' => ['any args']})
        expect(Resque.pop('restriction_normal')).to be_nil
        expect(Resque.pop('normal')).to be_nil
      end
    end
  end

  context 'reserve normal queue' do
    it "should push to restriction queue" do
      Resque.push('normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
      expect(Resque::Job.reserve('normal')).to be_nil
      expect(Resque.pop('normal')).to be_nil
      expect(Resque.pop('restriction_normal')).to eq('class' => 'OneHourRestrictionJob', 'args' => ['any args'])
    end
  end
end
