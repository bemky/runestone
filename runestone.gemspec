require File.expand_path("../lib/runestone/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "runestone"
  s.version     = Runestone::VERSION
  s.authors     = ["Jon Bracy"]
  s.email       = ["jonbracy@gmail.com"]
  s.homepage    = "https://github.com/malomalo/runestone"
  s.summary     = %q{Full Text Search for Active Record / Rails}
  s.description = %q{PostgreSQL Full Text Search for Active Record and Rails}
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # Developoment 
  s.add_development_dependency 'rake'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-reporters'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'faker'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'activejob', '>= 7.1'

  # Runtime
  s.add_runtime_dependency 'arel-extensions', '>= 7.0.0'
  s.add_runtime_dependency 'activerecord', '>= 7.1'
  s.add_runtime_dependency 'stream_parser', ">= 0.4"
end
