require "pg_party/version"
require "active_support"

ActiveSupport.on_load(:active_record) do
  require "pg_party/connection_handling"
  require "pg_party/model_methods"

  extend PgParty::ConnectionHandling
  extend PgParty::ModelMethods

  require "pg_party/connection_adapters/abstract_adapter"

  ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
    include PgParty::ConnectionAdapters::AbstractAdapter
  end
end
