require File.join(File.dirname(__FILE__) + '/../spec_helper')

describe Resque::Plugins::RestrictionJob do
  it "should follow the convention" do
    Resque::Plugin.lint(Resque::Plugins::RestrictionJob)
  end

  context "redis_key" do
    it "should get redis_key with different period" do
      Resque::Plugins::RestrictionJob.redis_key(:per_minute).should == "Resque::Plugins::RestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H-%M")}"
      Resque::Plugins::RestrictionJob.redis_key(:per_hour).should == "Resque::Plugins::RestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}"
      Resque::Plugins::RestrictionJob.redis_key(:per_day).should == "Resque::Plugins::RestrictionJob:#{Date.today}"
      Resque::Plugins::RestrictionJob.redis_key(:per_month).should == "Resque::Plugins::RestrictionJob:#{Date.today.strftime("%Y-%m")}"
      Resque::Plugins::RestrictionJob.redis_key(:per_year).should == "Resque::Plugins::RestrictionJob:#{Date.today.year}"
    end
  end
  
  context "settings" do
    it "get correct number to restriction jobs" do
      OneDayRestrictionJob.settings.should == {:per_day => 100}
      OneHourRestrictionJob.settings.should == {:per_hour => 10}
      MultipleRestrictionJob.settings.should == {:per_hour => 10, :per_minute => 2}
      MultiCallRestrictionJob.settings.should == {:per_hour => 10, :per_minute => 2}
    end
  end
  
  context "resque" do
    include PerformJob

    before(:each) do
      Resque.redis.flushall
    end
    
    it "should set execution number and decrement it when one job first executed" do
      result = perform_job(OneHourRestrictionJob, "any args")
      result.should be_true
      Resque.redis.get("OneHourRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}").should == "9"
    end

    it "should decrement execution number when one job executed" do
      Resque.redis.set("OneHourRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}", 6)
      result = perform_job(OneHourRestrictionJob, "any args")
      result.should be_true
      Resque.redis.get("OneHourRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}").should == "5"
    end

    it "should put the job into restriction queue when execution count <= 0" do
      Resque.redis.set("OneHourRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}", 0)
      result = perform_job(OneHourRestrictionJob, "any args")
      result.should_not be_true
      Resque.redis.get("OneHourRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}").should == "0"
      Resque.redis.lrange("queue:restriction", 0, -1).should == [Resque.encode(:class => "OneHourRestrictionJob", :args => ["any args"])]
    end

    context "multiple restrict" do
      it "should restrict per_minute" do
        result = perform_job(MultipleRestrictionJob, "any args")
        Resque.redis.get("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}").should == "9"
        Resque.redis.get("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H-%M")}").should == "1"
        result = perform_job(MultipleRestrictionJob, "any args")
        result = perform_job(MultipleRestrictionJob, "any args")
        Resque.redis.get("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}").should == "8"
        Resque.redis.get("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H-%M")}").should == "0"
      end

      it "should restrict per_hour" do
        Resque.redis.set("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}", 1)
        Resque.redis.set("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H-%M")}", 2)
        result = perform_job(MultipleRestrictionJob, "any args")
        Resque.redis.get("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}").should == "0"
        Resque.redis.get("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H-%M")}").should == "1"
        result = perform_job(MultipleRestrictionJob, "any args")
        Resque.redis.get("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H")}").should == "0"
        Resque.redis.get("MultipleRestrictionJob:#{Time.now.strftime("%Y-%m-%d-%H-%M")}").should == "1"
      end
    end
  end
end
