# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require "combustion"
require "timecop"
require "pry-byebug"
require "simplecov"
require "rake"

if ENV["CODE_COVERAGE"] == "true"
  SimpleCov.command_name Rails.gem_version.to_s

  SimpleCov.start do
    add_filter "spec"
  end
end

# make sure injected modules are required
require "pg_party/model/shared_methods"
require "pg_party/model/range_methods"
require "pg_party/model/list_methods"

Combustion.path = "spec/dummy"
Combustion.initialize! :active_record do
  config.eager_load = true
end

load "support/db.rake"

require "rspec/rails"
require "rspec/its"
require "database_cleaner"
require "support/uuid_matcher"
require "support/heredoc_matcher"
require "support/pg_dump_helper"

static_time = Date.current + 12.hours

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.mock_with :rspec do |c|
    c.verify_partial_doubles = true
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end

  config.around(:each) do |example|
    Timecop.freeze(static_time)
    PgParty.reset
    DatabaseCleaner.start
    example.run
    DatabaseCleaner.clean
  end
end
