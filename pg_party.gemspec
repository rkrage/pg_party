# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pg_party/version"

Gem::Specification.new do |spec|
  spec.name          = "pg_party"
  spec.version       = PgParty::VERSION
  spec.authors       = ["Ryan Krage"]
  spec.email         = ["krage.ryan@gmail.com"]

  spec.summary       = %q{ActiveRecord PostgreSQL Partitioning}
  spec.description   = %q{Migrations and model helpers for creating and managing PostgreSQL 10 partitions}
  spec.homepage      = "https://github.com/rkrage/pg_party"
  spec.license       = "MIT"

  spec.files         = Dir["LICENSE.txt", "README.md", "lib/**/*"]

  spec.require_paths = ["lib"]

  spec.add_runtime_dependency     "activerecord", "~> 5.0"

  spec.add_development_dependency "pg", "~> 0.20"
  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec-rails", "~> 3.6"
  spec.add_development_dependency "rspec-its", "~> 1.2"
  spec.add_development_dependency "pry-byebug", "~> 3.4"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.3"
  spec.add_development_dependency "appraisal", "~> 2.2"
  spec.add_development_dependency "combustion", "~> 0.7"
end
