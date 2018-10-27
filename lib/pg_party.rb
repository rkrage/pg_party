require "pg_party/version"
require "active_support"

ActiveSupport.on_load(:active_record) do
  require "pg_party/model/methods"

  extend PgParty::Model::Methods

  require "pg_party/adapter/abstract_methods"

  ActiveRecord::ConnectionAdapters::AbstractAdapter.include(
    PgParty::Adapter::AbstractMethods
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
