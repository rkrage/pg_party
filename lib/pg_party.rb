# frozen_string_literal: true

require "pg_party/version"
require "pg_party/config"
require "pg_party/cache"
require "active_support"

module PgParty
  @config = Config.new
  @cache = Cache.new

  class << self
    attr_reader :config, :cache

    def configure(&blk)
      blk.call(config)
    end

    def reset
      @config = Config.new
      @cache = Cache.new
    end
  end
end

ActiveSupport.on_load(:active_record) do
  require "pg_party/model/methods"

  extend PgParty::Model::Methods

  require "pg_party/adapter/abstract_methods"

  ActiveRecord::ConnectionAdapters::AbstractAdapter.include(
    PgParty::Adapter::AbstractMethods
  )

  require "active_record/tasks/postgresql_database_tasks"
  require "pg_party/hacks/postgresql_database_tasks"

  if Rails.gem_version >= Gem::Version.new("8.1")
    ActiveRecord::Tasks::PostgreSQLDatabaseTasks.prepend(
      PgParty::Hacks::PostgreSQLDatabaseTasks81
    )
  else
    ActiveRecord::Tasks::PostgreSQLDatabaseTasks.prepend(
      PgParty::Hacks::PostgreSQLDatabaseTasks
    )
  end

  begin
    require "active_record/connection_adapters/postgresql_adapter"
    require "pg_party/adapter/postgresql_methods"

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(
      PgParty::Adapter::PostgreSQLMethods
    )
  rescue LoadError
    # migration methods will not be available
  end
end
