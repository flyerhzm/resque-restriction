lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "resque/restriction/version"

Gem::Specification.new do |spec|
  spec.name          = "resque-restriction"
  spec.version       = Resque::Restriction::VERSION
  spec.authors       = ["Richard Huang"]
  spec.email         = ["flyerhzm@gmail.com"]

  spec.summary       = 'resque-restriction is an extension to resque queue system that restricts the execution number of certain jobs in a period time.'
  spec.description   = 'resque-restriction is an extension to resque queue system that restricts the execution number of certain jobs in a period time, the exceeded jobs will be executed at the next period.'
  spec.homepage      = 'https://github.com/flyerhzm/resque-restriction'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "resque", ">= 1.7.0"
end
