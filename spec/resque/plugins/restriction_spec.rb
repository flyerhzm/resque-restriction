require 'spec_helper'

RSpec.describe Resque::Plugins::Restriction do
  it "should follow the convention" do
    Resque::Plugin.lint(Resque::Plugins::Restriction)
  end

  describe ".redis_key" do
    it "should get redis_key with different period" do
      expect(MyJob.redis_key(:per_minute)).to eq "restriction:MyJob:#{Time.now.to_i / 60}"
      expect(MyJob.redis_key(:per_hour)).to eq "restriction:MyJob:#{Time.now.to_i / (60 * 60)}"
      expect(MyJob.redis_key(:per_day)).to eq "restriction:MyJob:#{Time.now.to_i / (24 * 60 * 60)}"
      expect(MyJob.redis_key(:per_month)).to eq "restriction:MyJob:#{Date.today.strftime("%Y-%m")}"
      expect(MyJob.redis_key(:per_year)).to eq "restriction:MyJob:#{Date.today.year}"
      expect(MyJob.redis_key(:per_minute_and_foo, 'foo' => 'bar')).to eq "restriction:MyJob:bar:#{Time.now.to_i / 60}"
    end

    it "should accept customization" do
      expect(MyJob.redis_key(:per_1800)).to eq "restriction:MyJob:#{Time.now.to_i / 1800}"
      expect(MyJob.redis_key(:per_7200)).to eq "restriction:MyJob:#{Time.now.to_i / 7200}"
      expect(MyJob.redis_key(:per_1800_and_foo, 'foo' => 'bar')).to eq "restriction:MyJob:bar:#{Time.now.to_i / 1800}"
    end
  end

  describe ".seconds" do
    it "should get seconds with different period" do
      expect(MyJob.seconds(:per_minute)).to eq 60
      expect(MyJob.seconds(:per_hour)).to eq 60 * 60
      expect(MyJob.seconds(:per_day)).to eq 24 * 60 * 60
      expect(MyJob.seconds(:per_week)).to eq 7 * 24 * 60 * 60
      expect(MyJob.seconds(:per_month)).to eq 31 * 24 * 60 * 60
      expect(MyJob.seconds(:per_year)).to eq 366 * 24 * 60 * 60
      expect(MyJob.seconds(:per_minute_and_foo)).to eq 60
    end

    it "should accept customization" do
      expect(MyJob.seconds(:per_1800)).to eq 1800
      expect(MyJob.seconds(:per_7200)).to eq 7200
      expect(MyJob.seconds(:per_1800_and_foo)).to eq 1800
    end
  end

  describe ".restriction_settings" do
    it "get correct number to restriction jobs" do
      expect(OneDayRestrictionJob.restriction_settings).to eq(:per_day => 100)
      expect(OneHourRestrictionJob.restriction_settings).to eq(:per_hour => 10)
      expect(MultipleRestrictionJob.restriction_settings).to eq(:per_hour => 10, :per_300 => 2)
      expect(MultiCallRestrictionJob.restriction_settings).to eq(:per_hour => 10, :per_300 => 2)
    end
  end

  describe ".reach_restriction?" do
    before(:example) do
      Resque.redis.flushall
    end

    it "should set execution number and decrement it when one job first executed" do
      expect(OneHourRestrictionJob.reach_restriction?("any args")).to be_falsey
      expect(Resque.redis.get(OneHourRestrictionJob.redis_key(:per_hour))).to eq "9"
    end

    it "should use restriction_identifier to set exclusive execution counts" do
      expect(IdentifiedRestrictionJob.reach_restriction?(1)).to be_falsey
      expect(IdentifiedRestrictionJob.reach_restriction?(1)).to be_falsey
      expect(IdentifiedRestrictionJob.reach_restriction?(2)).to be_falsey

      expect(Resque.redis.get(IdentifiedRestrictionJob.redis_key(:per_hour, 1))).to eq "8"
      expect(Resque.redis.get(IdentifiedRestrictionJob.redis_key(:per_hour, 2))).to eq "9"
    end

    it "should decrement execution number when one job executed" do
      Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), 6)
      expect(OneHourRestrictionJob.reach_restriction?("any args")).to be_falsey

      expect(Resque.redis.get(OneHourRestrictionJob.redis_key(:per_hour))).to eq "5"
    end

    it "should put the job into restriction queue when execution count < 0" do
      Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), 0)
      expect(OneHourRestrictionJob.reach_restriction?("any args")).to be_truthy
      expect(Resque.redis.get(OneHourRestrictionJob.redis_key(:per_hour))).to eq "0"
    end

    describe "expiration of period keys" do
      class MyJob
        extend Resque::Plugins::Restriction

        def self.perform(*args); end
      end

      shared_examples_for "expiration" do
        before(:example) do
          MyJob.restrict period => 10
        end

        context "when the key is not set" do
          it "should mark period keys to expire" do
            MyJob.reach_restriction?("any args")
            expect(Resque.redis.ttl(MyJob.redis_key(period))).to eq MyJob.seconds(period)
          end
        end

        context "when the key is set" do
          before(:example) do
            Resque.redis.set(MyJob.redis_key(period), 5)
          end

          it "should not mark period keys to expire" do
            MyJob.reach_restriction?("any args")
            expect(Resque.redis.ttl(MyJob.redis_key(period))).to eq -1
          end
        end
      end

      describe "per minute" do
        def period
          :per_minute
        end

        it_should_behave_like "expiration"
      end

      describe "per hour" do
        def period
          :per_hour
        end

        it_should_behave_like "expiration"
      end

      describe "per day" do
        def period
          :per_day
        end

        it_should_behave_like "expiration"
      end

      describe "per week" do
        def period
          :per_week
        end

        it_should_behave_like "expiration"
      end

      describe "per month" do
        def period
          :per_month
        end

        it_should_behave_like "expiration"
      end

      describe "per year" do
        def period
          :per_year
        end

        it_should_behave_like "expiration"
      end

      describe "per custom period" do
        def period
          :per_359
        end

        it_should_behave_like "expiration"
      end
    end

    context "multiple restrict" do
      it "should restrict per_minute" do
        MultipleRestrictionJob.reach_restriction?("any args")
        expect(Resque.redis.get(MultipleRestrictionJob.redis_key(:per_hour))).to eq "9"
        expect(Resque.redis.get(MultipleRestrictionJob.redis_key(:per_300))).to eq "1"
        MultipleRestrictionJob.reach_restriction?("any args")
        MultipleRestrictionJob.reach_restriction?("any args")
        expect(Resque.redis.get(MultipleRestrictionJob.redis_key(:per_hour))).to eq "8"
        expect(Resque.redis.get(MultipleRestrictionJob.redis_key(:per_300))).to eq "0"
      end

      it "should restrict per_hour" do
        Resque.redis.set(MultipleRestrictionJob.redis_key(:per_hour), 1)
        Resque.redis.set(MultipleRestrictionJob.redis_key(:per_300), 2)
        MultipleRestrictionJob.reach_restriction?("any args")
        expect(Resque.redis.get(MultipleRestrictionJob.redis_key(:per_hour))).to eq "0"
        expect(Resque.redis.get(MultipleRestrictionJob.redis_key(:per_300))).to eq "1"
        MultipleRestrictionJob.reach_restriction?("any args")
        expect(Resque.redis.get(MultipleRestrictionJob.redis_key(:per_hour))).to eq "0"
        expect(Resque.redis.get(MultipleRestrictionJob.redis_key(:per_300))).to eq "1"
      end
    end
  end

  describe '.reset_concurrent_restriction' do
    it "should increment execution number when concurrent job completes" do
      ConcurrentRestrictionJob.reset_concurrent_restriction("any args")
      expect(Resque.redis.get(ConcurrentRestrictionJob.redis_key(:concurrent))).to eq "1"
    end
  end
end
