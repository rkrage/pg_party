# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pg_party/version"

Gem::Specification.new do |spec|
  spec.name    = "pg_party"
  spec.version = PgParty::VERSION
  spec.authors = ["Ryan Krage"]
  spec.email   = ["krage.ryan@gmail.com"]

  spec.summary     = %q{ActiveRecord PostgreSQL Partitioning}
  spec.description = %q{Migrations and model helpers for creating and managing PostgreSQL 10 partitions}
  spec.homepage    = "https://github.com/rkrage/pg_party"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["LICENSE.txt", "README.md", "lib/**/*"]

  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activerecord", ">= 6.1", "< 8.1"
  spec.add_runtime_dependency "parallel", "~> 1.0"

  spec.add_development_dependency "appraisal", "~> 2.2"
  spec.add_development_dependency "byebug", "~> 11.0"
  spec.add_development_dependency "combustion", "~> 1.3"
  spec.add_development_dependency "nokogiri", ">= 1.10.4", "< 2.0"
  spec.add_development_dependency "pry-byebug", "~> 3.7"
  spec.add_development_dependency "rake", "~> 12.3"
  spec.add_development_dependency "rspec-its", "~> 1.3"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.4"
  spec.add_development_dependency "simplecov", "~> 0.21"
  spec.add_development_dependency "timecop", "~> 0.9"
  spec.add_development_dependency "psych", "~> 3.3" # psych 4 ships with ruby 3.1 and breaks a lot of things
end
