require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

RSpec::Core::RakeTask.new(:ci) do |t|
  t.rspec_opts = [
    "--format progress",
    "--format RspecJunitFormatter",
    "--no-color",
    "-o spec/reports/rspec.xml"
  ]
end

task :default => :spec
