# frozen_string_literal: true

module PgParty
  module Hacks
    # We should really use ActiveRecord::SchemaDumper.ignore_tables
    # but it appears there's a bug in the code that generates the args
    # for pg_dump. I believe we need to exclude based on the fully
    # qualified name (or a pattern like *.table_name) but the Rails
    # code does not do this and we need to hack into low-level methods.
    module PostgreSQLDatabaseTasks
      def run_cmd(cmd, args, action)
        if action != "dumping" || !PgParty.config.schema_exclude_partitions
          return super
        end

        partitions = ActiveRecord::Base.connection.select_values(<<-SQL, "SCHEMA")
          SELECT CONCAT(pg_namespace.nspname, '.', child.relname)
          FROM pg_inherits
            JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
            JOIN pg_class child  ON pg_inherits.inhrelid  = child.oid
            JOIN pg_namespace    ON parent.relnamespace = pg_namespace.oid
          WHERE parent.relkind = 'p'
        SQL

        excluded_tables = partitions.flat_map { |table| ["-T", table] }

        super(cmd, args + excluded_tables, action)
      end
    end

    module PostgreSQLDatabaseTasks81
      def run_cmd(cmd, *args)
        if cmd != "pg_dump" || !PgParty.config.schema_exclude_partitions
          return super
        end

        partitions = ActiveRecord::Base.connection.select_values(<<-SQL, "SCHEMA")
          SELECT CONCAT(pg_namespace.nspname, '.', child.relname)
          FROM pg_inherits
            JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
            JOIN pg_class child  ON pg_inherits.inhrelid  = child.oid
            JOIN pg_namespace    ON parent.relnamespace = pg_namespace.oid
          WHERE parent.relkind = 'p'
        SQL

        excluded_tables = partitions.flat_map { |table| ["-T", table] }

        super(cmd, *args, *excluded_tables)
      end
    end
  end
end
