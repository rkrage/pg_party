# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

RSpec::Core::RakeTask.new(:ci) do |t|
  ENV["CODE_COVERAGE"] = "true"

  gemfile = File.basename(ENV.fetch("BUNDLE_GEMFILE", ""), ".gemfile")

  if gemfile.empty? || gemfile == "Gemfile"
    output_prefix = "default"
  else
    output_prefix = gemfile
  end

  t.rspec_opts = [
    "--format progress",
    "--format RspecJunitFormatter",
    "--no-color",
    "-o spec/results/#{output_prefix}_rspec.xml"
  ]
end

task :default => :spec
