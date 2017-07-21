module PgParty
  module ConnectionHandling
    def establish_connection(*args)
      super.tap do
        if defined?(ActiveRecord::ConnectionAdapters::AbstractAdapter)
          require "pg_party/abstract_schema_statements"
          ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, PgParty::AbstractSchemaStatements)
        end

        if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
          require "pg_party/postgresql_schema_statements"
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:include, PgParty::PostgreSQLSchemaStatements)
        end
      end
    end
  end
end
