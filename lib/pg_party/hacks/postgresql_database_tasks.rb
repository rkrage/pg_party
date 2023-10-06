# frozen_string_literal: true

module PgParty
  module Hacks
    module PostgreSQLDatabaseTasks
      def run_cmd(cmd, args, action)
        if action != "dumping" || !PgParty.config.schema_exclude_partitions
          return super
        end

        partitions = begin
          # puts "!!!!!!!!"
          ActiveRecord::Base.connection.select_values(<<-SQL)
            SELECT
              inhrelid::regclass::text
            FROM
              pg_inherits
            JOIN pg_class AS p ON inhparent = p.oid
            WHERE p.relkind = 'p'
          SQL
        rescue StandardError
          []
        end

        excluded_tables = partitions.flat_map { |table| ["-T", "*.#{table}"] }

        super(cmd, args + excluded_tables, action)
      end
    end
  end
end
