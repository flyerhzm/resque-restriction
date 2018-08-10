require 'spec_helper'

RSpec.describe Resque::Job do
  before(:example) do
    Resque.redis.flushall
  end

  context 'reserve' do
    context 'reach restriction' do
      it "should do nothing" do
        Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), -1)
        Resque.push('normal', class: 'OneHourRestrictionJob', args: ['any args'])
        expect(Resque::Job.reserve('normal')).to be_nil
        expect(Resque.pop('normal')).not_to be_nil
      end
    end

    context 'not reach restriction' do
      it "should pop job" do
        Resque.push('normal', class: 'OneHourRestrictionJob', args: ['any args'])
        expect(Resque::Job.reserve('normal')).to eq Resque::Job.new('normal', 'class' => 'OneHourRestrictionJob', 'args' => ['any args'])
        expect(Resque.pop('normal')).to be_nil
      end
    end
  end
end
