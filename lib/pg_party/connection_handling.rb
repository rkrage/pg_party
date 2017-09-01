module PgParty
  module ConnectionHandling
    def establish_connection(*args)
      super.tap do
        if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
          require "pg_party/connection_adapters/postgresql_adapter"

          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
            include PgParty::ConnectionAdapters::PostgreSQLAdapter
          end
        end
      end
    end
  end
end
