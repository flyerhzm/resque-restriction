require File.join(File.dirname(__FILE__) + '/../spec_helper')

describe Resque::Plugins::RestrictionJob do
  it "should follow the convention" do
    Resque::Plugin.lint(Resque::Plugins::RestrictionJob)
  end
  
  context "settings" do
    it "get correct number to restriction jobs" do
      DefaultRestrictionJob.number.should == 1000
      TenNumberRestrictionJob.number.should == 10
    end
    
    it "get correct period to restriction jobs" do
      DefaultRestrictionJob.period.should == 60*60*24
      OneHourRestrictionJob.period.should == 60*60
    end
  end
  
  context "resque" do
    before(:each) do
      Resque.redis.flush_all
      @bogus_args = "bogus_args"
    end
    
    it "should set key for restriction number" do
      Resque.expects(:enqueue).returns(true)
      Resque.enqueue(DefaultRestrictionJob, @bogus_args)
      Resque.redis.keys('*').include?("resque:DefaultRestrictionJob:#{Date.today}")
      Resque.redis.get("resque:DefaultRestrictionJob:#{Date.today}").should == 1000
    end
  end
end