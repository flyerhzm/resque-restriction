require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "resque-restriction"
    gemspec.summary = "resque-restriction is an extension to resque queue system that restricts the execution number of certain jobs in a period time."
    gemspec.description = "resque-restriction is an extension to resque queue system that restricts the execution number of certain jobs in a period time, the exceeded jobs will be executed at the next period."
    gemspec.email = "flyerhzm@gmail.com"
    gemspec.homepage = "http://github.com/flyerhzm/resque-restriction"
    gemspec.authors = ["Richard Huang"]
    gemspec.add_dependency "resque", ">=1.7.0"
  end
  Jeweler::GemcutterTasks.new
rescue
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end
