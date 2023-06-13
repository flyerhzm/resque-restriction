require 'spec_helper'

RSpec.describe Resque::Plugins::Restriction do
  it "should follow the convention" do
    Resque::Plugin.lint(Resque::Plugins::Restriction)
  end

  context "resque_restriction_redis_key" do
    it "should get resque_restriction_redis_key with different period" do
      expect(MyJob.resque_restriction_redis_key(:per_minute)).to eq "restriction:MyJob:#{Time.now.to_i / 60}"
      expect(MyJob.resque_restriction_redis_key(:per_hour)).to eq "restriction:MyJob:#{Time.now.to_i / (60*60)}"
      expect(MyJob.resque_restriction_redis_key(:per_day)).to eq "restriction:MyJob:#{Time.now.to_i / (24*60*60)}"
      expect(MyJob.resque_restriction_redis_key(:per_month)).to eq "restriction:MyJob:#{Date.today.strftime("%Y-%m")}"
      expect(MyJob.resque_restriction_redis_key(:per_year)).to eq "restriction:MyJob:#{Date.today.year}"
      expect(MyJob.resque_restriction_redis_key(:per_minute_and_foo, 'foo' => 'bar')).to eq "restriction:MyJob:bar:#{Time.now.to_i / 60}"
    end

    it "should accept customization" do
      expect(MyJob.resque_restriction_redis_key(:per_1800)).to eq "restriction:MyJob:#{Time.now.to_i / 1800}"
      expect(MyJob.resque_restriction_redis_key(:per_7200)).to eq "restriction:MyJob:#{Time.now.to_i / 7200}"
      expect(MyJob.resque_restriction_redis_key(:per_1800_and_foo, 'foo' => 'bar')).to eq "restriction:MyJob:bar:#{Time.now.to_i / 1800}"
    end
  end

  context "seconds" do
    it "should get seconds with different period" do
      expect(MyJob.seconds(:per_minute)).to eq 60
      expect(MyJob.seconds(:per_hour)).to eq 60*60
      expect(MyJob.seconds(:per_day)).to eq 24*60*60
      expect(MyJob.seconds(:per_week)).to eq 7*24*60*60
      expect(MyJob.seconds(:per_month)).to eq 31*24*60*60
      expect(MyJob.seconds(:per_year)).to eq 366*24*60*60
      expect(MyJob.seconds(:per_minute_and_foo)).to eq 60
    end

    it "should accept customization" do
      expect(MyJob.seconds(:per_1800)).to eq 1800
      expect(MyJob.seconds(:per_7200)).to eq 7200
      expect(MyJob.seconds(:per_1800_and_foo)).to eq 1800
    end
  end

  context "settings" do
    it "get correct number to restriction jobs" do
      expect(OneDayRestrictionJob.settings).to eq({:per_day => 100})
      expect(OneHourRestrictionJob.settings).to eq({:per_hour => 10})
      expect(MultipleRestrictionJob.settings).to eq({:per_hour => 10, :per_300 => 2})
      expect(MultiCallRestrictionJob.settings).to eq({:per_hour => 10, :per_300 => 2})
    end
  end

  context 'restriction_queue_name' do
    it 'concats restriction queue prefix with queue name' do
      expect(MyJob.restriction_queue_name).to eq("#{Resque::Plugins::Restriction::RESTRICTION_QUEUE_PREFIX}_awesome_queue_name")
    end
  end

  context "resque" do
    include PerformJob

    before(:example) do
      Resque.redis.redis.flushall
    end

    it "should set execution number and decrement it when one job first executed" do
      result = perform_job(OneHourRestrictionJob, "any args")
      expect(Resque.redis.get(OneHourRestrictionJob.resque_restriction_redis_key(:per_hour))).to eq "9"
    end

    it "should use restriction_identifier to set exclusive execution counts" do
      result = perform_job(IdentifiedRestrictionJob, 1)
      result = perform_job(IdentifiedRestrictionJob, 1)
      result = perform_job(IdentifiedRestrictionJob, 2)

      expect(Resque.redis.get(IdentifiedRestrictionJob.resque_restriction_redis_key(:per_hour, 1))).to eq "8"
      expect(Resque.redis.get(IdentifiedRestrictionJob.resque_restriction_redis_key(:per_hour, 2))).to eq "9"
    end

    it "should decrement execution number when one job executed" do
      Resque.redis.set(OneHourRestrictionJob.resque_restriction_redis_key(:per_hour), 6)
      result = perform_job(OneHourRestrictionJob, "any args")

      expect(Resque.redis.get(OneHourRestrictionJob.resque_restriction_redis_key(:per_hour))).to eq "5"
    end

    it "should increment execution number when concurrent job completes" do
      t = Thread.new do
        perform_job(ConcurrentRestrictionJob, "any args")
      end
      sleep 0.1
      expect(Resque.redis.get(ConcurrentRestrictionJob.resque_restriction_redis_key(:concurrent))).to eq "0"
      t.join
      expect(Resque.redis.get(ConcurrentRestrictionJob.resque_restriction_redis_key(:concurrent))).to eq "1"
    end

    it "should increment execution number when concurrent job fails" do
      expect(ConcurrentRestrictionJob).to receive(:perform).and_raise("bad")
      perform_job(ConcurrentRestrictionJob, "any args") rescue nil
      expect(Resque.redis.get(ConcurrentRestrictionJob.resque_restriction_redis_key(:concurrent))).to eq "1"
    end

    it "should put the job into restriction queue when execution count < 0" do
      Resque.redis.set(OneHourRestrictionJob.resque_restriction_redis_key(:per_hour), 0)
      result = perform_job(OneHourRestrictionJob, "any args")
      # expect(result).to_not be(true)
      expect(Resque.redis.get(OneHourRestrictionJob.resque_restriction_redis_key(:per_hour))).to eq "0"
      expect(Resque.redis.lrange("queue:restriction_normal", 0, -1)).to eq [Resque.encode(:class => "OneHourRestrictionJob", :args => ["any args"])]
    end

    describe "expiration of period keys" do
      class MyJob
        extend Resque::Plugins::Restriction

        def self.perform(*args)
        end
      end

      shared_examples_for "expiration" do
        before(:example) do
          MyJob.restrict period => 10
        end

        context "when the key is not set" do
          it "should mark period keys to expire" do
            perform_job(MyJob, "any args")
            expect(Resque.redis.ttl(MyJob.resque_restriction_redis_key(period))).to eq MyJob.seconds(period)
          end
        end

        context "when the key is set" do
          before(:example) do
            Resque.redis.set(MyJob.resque_restriction_redis_key(period), 5)
          end

          it "should not mark period keys to expire" do
            perform_job(MyJob, "any args")
            expect(Resque.redis.ttl(MyJob.resque_restriction_redis_key(period))).to eq -1
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
        result = perform_job(MultipleRestrictionJob, "any args")
        expect(Resque.redis.get(MultipleRestrictionJob.resque_restriction_redis_key(:per_hour))).to eq "9"
        expect(Resque.redis.get(MultipleRestrictionJob.resque_restriction_redis_key(:per_300))).to eq "1"
        result = perform_job(MultipleRestrictionJob, "any args")
        result = perform_job(MultipleRestrictionJob, "any args")
        expect(Resque.redis.get(MultipleRestrictionJob.resque_restriction_redis_key(:per_hour))).to eq "8"
        expect(Resque.redis.get(MultipleRestrictionJob.resque_restriction_redis_key(:per_300))).to eq "0"
      end

      it "should restrict per_hour" do
        Resque.redis.set(MultipleRestrictionJob.resque_restriction_redis_key(:per_hour), 1)
        Resque.redis.set(MultipleRestrictionJob.resque_restriction_redis_key(:per_300), 2)
        result = perform_job(MultipleRestrictionJob, "any args")
        expect(Resque.redis.get(MultipleRestrictionJob.resque_restriction_redis_key(:per_hour))).to eq "0"
        expect(Resque.redis.get(MultipleRestrictionJob.resque_restriction_redis_key(:per_300))).to eq "1"
        result = perform_job(MultipleRestrictionJob, "any args")
        expect(Resque.redis.get(MultipleRestrictionJob.resque_restriction_redis_key(:per_hour))).to eq "0"
        expect(Resque.redis.get(MultipleRestrictionJob.resque_restriction_redis_key(:per_300))).to eq "1"
      end
    end

    context "repush" do
      it "should push restricted jobs onto restriction queue" do
        Resque.redis.set(OneHourRestrictionJob.resque_restriction_redis_key(:per_hour), -1)
        expect(Resque).to receive(:push).once.with('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
        expect(OneHourRestrictionJob.repush('any args')).to be(true)
      end

      it "should not push unrestricted jobs onto restriction queue" do
        Resque.redis.set(OneHourRestrictionJob.resque_restriction_redis_key(:per_hour), 1)
        expect(Resque).not_to receive(:push)
        expect(OneHourRestrictionJob.repush('any args')).to be(false)
      end
    end
  end
end
