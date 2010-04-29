require 'rake'
require 'spec/rake/spectask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :spec

desc 'Generate documentation for the resque-restriction plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'resque_restriction'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Run all specs in spec directory"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "resque-restriction"
    gemspec.summary = "resque-restriction is an extension to resque queue system that restricts the execution number of certain jobs in a period time."
    gemspec.description = "resque-restriction is an extension to resque queue system that restricts the execution number of certain jobs in a period time."
    gemspec.email = "flyerhzm@gmail.com"
    gemspec.homepage = "http://github.com/flyerhzm/resque-restriction"
    gemspec.authors = ["Richard Huang"]
    gemspec.add_dependency "resque", ">=1.7.0"
  end
  Jeweler::GemcutterTasks.new
rescue
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end