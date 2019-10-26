# frozen_string_literal: true

module PgParty
  module Hacks
    module DatabaseTasks
      def structure_dump(*)
        old_ignore_list = ActiveRecord::SchemaDumper.ignore_tables
        new_ignore_list = partitions.map { |table| "*.#{table}" }

        ActiveRecord::SchemaDumper.ignore_tables = old_ignore_list + new_ignore_list

        super
      ensure
        ActiveRecord::SchemaDumper.ignore_tables = old_ignore_list
      end

      def partitions
        ActiveRecord::Base.connection.select_values(
          "SELECT DISTINCT inhrelid::regclass::text FROM pg_inherits"
        )
      rescue
        []
      end
    end
  end
end
