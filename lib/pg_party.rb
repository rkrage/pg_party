require "pg_party/version"
require "active_support"

ActiveSupport.on_load(:active_record) do
  require "pg_party/model/methods"

  extend PgParty::Model::Methods

  require "pg_party/adapter/abstract_methods"

  ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
    include PgParty::Adapter::AbstractMethods
  end

  require "pg_party/adapter/postgresql_methods"
  require "active_record/connection_adapters/postgresql_adapter"

  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    include PgParty::Adapter::PostgreSQLMethods
  end
end
