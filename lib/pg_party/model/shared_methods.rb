require "pg_party/model_decorator"

module PgParty
  module Model
    module SharedMethods
      def reset_primary_key
        PgParty::ModelDecorator.new(self).partition_primary_key
      end

      def table_exists?
        return @table_exists if defined?(@table_exists)

        @table_exists = PgParty::ModelDecorator.new(self).partition_table_exists?
      end

      def partitions
        PgParty::ModelDecorator.new(self).partitions
      end

      def in_partition(*args)
        PgParty::ModelDecorator.new(self).in_partition(*args)
      end

      def partition_key_eq(*args)
        PgParty::ModelDecorator.new(self).partition_key_eq(*args)
      end
    end
  end
end
