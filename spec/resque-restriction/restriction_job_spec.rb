require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Resque::Plugins::RestrictionJob do
  it "should follow the convention" do
    Resque::Plugin.lint(Resque::Plugins::RestrictionJob)
  end

  context "redis_key" do
    it "should get redis_key with different period" do
      Resque::Plugins::RestrictionJob.redis_key(:per_minute).should == "Resque::Plugins::RestrictionJob:#{Time.now.to_i / 60}"
      Resque::Plugins::RestrictionJob.redis_key(:per_hour).should == "Resque::Plugins::RestrictionJob:#{Time.now.to_i / (60*60)}"
      Resque::Plugins::RestrictionJob.redis_key(:per_day).should == "Resque::Plugins::RestrictionJob:#{Time.now.to_i / (24*60*60)}"
      Resque::Plugins::RestrictionJob.redis_key(:per_month).should == "Resque::Plugins::RestrictionJob:#{Date.today.strftime("%Y-%m")}"
      Resque::Plugins::RestrictionJob.redis_key(:per_year).should == "Resque::Plugins::RestrictionJob:#{Date.today.year}"
    end

    it "should accept customization" do
      Resque::Plugins::RestrictionJob.redis_key(:per_1800).should == "Resque::Plugins::RestrictionJob:#{Time.now.to_i / 1800}"
      Resque::Plugins::RestrictionJob.redis_key(:per_7200).should == "Resque::Plugins::RestrictionJob:#{Time.now.to_i / 7200}"
    end
  end

  context "settings" do
    it "get correct number to restriction jobs" do
      OneDayRestrictionJob.settings.should == {:per_day => 100}
      OneHourRestrictionJob.settings.should == {:per_hour => 10}
      MultipleRestrictionJob.settings.should == {:per_hour => 10, :per_300 => 2}
      MultiCallRestrictionJob.settings.should == {:per_hour => 10, :per_300 => 2}
    end
  end

  context "resque" do
    include PerformJob

    before(:each) do
      Resque.redis.flushall
    end

    it "should set execution number and decrement it when one job first executed" do
      result = perform_job(OneHourRestrictionJob, "any args")
      expect(result).to be(true)
      Resque.redis.get(OneHourRestrictionJob.redis_key(:per_hour)).should == "9"
    end

    it "should use restriction_identifier to set exclusive execution counts" do
      result = perform_job(IdentifiedRestrictionJob, 1)
      expect(result).to be(true)
      result = perform_job(IdentifiedRestrictionJob, 1)
      expect(result).to be(true)
      result = perform_job(IdentifiedRestrictionJob, 2)
      expect(result).to be(true)
      Resque.redis.get(IdentifiedRestrictionJob.redis_key(:per_hour, 1)).should == "8"
      Resque.redis.get(IdentifiedRestrictionJob.redis_key(:per_hour, 2)).should == "9"
    end

    it "should decrement execution number when one job executed" do
      Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), 6)
      result = perform_job(OneHourRestrictionJob, "any args")
      expect(result).to be(true)
      Resque.redis.get(OneHourRestrictionJob.redis_key(:per_hour)).should == "5"
    end

    it "should increment execution number when concurrent job completes" do
      t = Thread.new do
        result = perform_job(ConcurrentRestrictionJob, "any args")
        expect(result).to be(true)
      end
      sleep 0.1
      Resque.redis.get(ConcurrentRestrictionJob.redis_key(:concurrent)).should == "0"
      t.join
      Resque.redis.get(ConcurrentRestrictionJob.redis_key(:concurrent)).should == "1"
    end

    it "should increment execution number when concurrent job fails" do
      ConcurrentRestrictionJob.should_receive(:perform).and_raise("bad")
      perform_job(ConcurrentRestrictionJob, "any args") rescue nil
      Resque.redis.get(ConcurrentRestrictionJob.redis_key(:concurrent)).should == "1"
    end

    it "should put the job into restriction queue when execution count < 0" do
      Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), 0)
      result = perform_job(OneHourRestrictionJob, "any args")
      expect(result).to_not be(true)
      Resque.redis.get(OneHourRestrictionJob.redis_key(:per_hour)).should == "0"
      Resque.redis.lrange("queue:restriction_normal", 0, -1).should == [Resque.encode(:class => "OneHourRestrictionJob", :args => ["any args"])]
    end

    describe "expiration of period keys" do
      class MyJob
        extend Resque::Plugins::Restriction

        def self.perform(*args)
        end
      end

      shared_examples_for "expiration" do
        before(:each) do
          MyJob.restrict period => 10
        end

        context "when the key is not set" do
          it "should mark period keys to expire" do
            perform_job(MyJob, "any args")
            Resque.redis.ttl(MyJob.redis_key(period)).should == MyJob.seconds(period)
          end
        end

        context "when the key is set" do
          before(:each) do
            Resque.redis.set(MyJob.redis_key(period), 5)
          end

          it "should not mark period keys to expire" do
            perform_job(MyJob, "any args")
            Resque.redis.ttl(MyJob.redis_key(period)).should == -1
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
        Resque.redis.get(MultipleRestrictionJob.redis_key(:per_hour)).should == "9"
        Resque.redis.get(MultipleRestrictionJob.redis_key(:per_300)).should == "1"
        result = perform_job(MultipleRestrictionJob, "any args")
        result = perform_job(MultipleRestrictionJob, "any args")
        Resque.redis.get(MultipleRestrictionJob.redis_key(:per_hour)).should == "8"
        Resque.redis.get(MultipleRestrictionJob.redis_key(:per_300)).should == "0"
      end

      it "should restrict per_hour" do
        Resque.redis.set(MultipleRestrictionJob.redis_key(:per_hour), 1)
        Resque.redis.set(MultipleRestrictionJob.redis_key(:per_300), 2)
        result = perform_job(MultipleRestrictionJob, "any args")
        Resque.redis.get(MultipleRestrictionJob.redis_key(:per_hour)).should == "0"
        Resque.redis.get(MultipleRestrictionJob.redis_key(:per_300)).should == "1"
        result = perform_job(MultipleRestrictionJob, "any args")
        Resque.redis.get(MultipleRestrictionJob.redis_key(:per_hour)).should == "0"
        Resque.redis.get(MultipleRestrictionJob.redis_key(:per_300)).should == "1"
      end
    end

    context "repush" do
      it "should push restricted jobs onto restriction queue" do
        Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), -1)
        Resque.should_receive(:push).once.with('restriction_normal', :class => 'OneHourRestrictionJob', :args => ['any args'])
        expect(OneHourRestrictionJob.repush('any args')).to be(true)
      end

      it "should not push unrestricted jobs onto restriction queue" do
        Resque.redis.set(OneHourRestrictionJob.redis_key(:per_hour), 1)
        Resque.should_not_receive(:push)
        expect(OneHourRestrictionJob.repush('any args')).to be(false)
      end

    end
  end
end
