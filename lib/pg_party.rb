require "pg_party/version"
require "active_support"

ActiveSupport.on_load(:active_record) do
  require "pg_party/connection_handling"
  require "pg_party/model_helpers"
  require "pg_party/connection_adapters/abstract_adapter"

  extend PgParty::ConnectionHandling
  extend PgParty::ModelHelpers

  ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
    include PgParty::ConnectionAdapters::AbstractAdapter
  end
end
