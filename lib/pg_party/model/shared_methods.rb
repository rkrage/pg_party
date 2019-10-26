# frozen_string_literal: true

require "pg_party/model_decorator"

module PgParty
  module Model
    module SharedMethods
      def reset_primary_key
        if self != base_class
          base_class.primary_key
        elsif partition_name = partitions.first
          in_partition(partition_name).get_primary_key(base_class.name)
        else
          get_primary_key(base_class.name)
        end
      end

      def table_exists?
        target_table = partitions.first || table_name

        connection.schema_cache.data_source_exists?(target_table)
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
