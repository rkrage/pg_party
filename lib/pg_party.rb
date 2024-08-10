# frozen_string_literal: true

require "pg_party/version"
require "pg_party/config"
require "pg_party/cache"
require "active_support"

# TODO: remove me, see: https://github.com/rkrage/pg_party/pull/83#issuecomment-2282203018
if Gem::Version.new(Rails::VERSION::STRING) >= Gem::Version.new("7.2.0") && Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new("8.0.0")
  module ActiveRecord
    module AttributeMethods
      module PrimaryKey
        module ClassMethods
          def primary_key
            if PRIMARY_KEY_NOT_SET.equal?(@primary_key)
              @primary_key = reset_primary_key
            end
            @primary_key
          end
        end
      end
    end
  end
end

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

  ActiveRecord::Tasks::PostgreSQLDatabaseTasks.prepend(
    PgParty::Hacks::PostgreSQLDatabaseTasks
  )

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
