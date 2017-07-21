require "pg_party/version"
require "active_support"

ActiveSupport.on_load(:active_record) do
  require "pg_party/connection_handling"
  ActiveRecord::Base.send(:extend, PgParty::ConnectionHandling)
end
