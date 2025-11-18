# frozen_string_literal: true

module PgParty
  module Hacks
    module SchemaDumper
      def ignored?(table_name)
        return true if super

        return false unless PgParty.config.schema_exclude_partitions

        @partition_tables ||= @connection.select_values(<<-SQL, "SCHEMA")
          SELECT inhrelid::regclass::text
          FROM pg_inherits
          JOIN pg_class AS p ON inhparent = p.oid
          WHERE p.relkind = 'p'
        SQL

        @partition_tables.include?(table_name)
      end
    end
  end
end
