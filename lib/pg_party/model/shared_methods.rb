# frozen_string_literal: true

require "pg_party/model_decorator"

module PgParty
  module Model
    module SharedMethods
      def reset_primary_key
        return (self.primary_key = base_class.primary_key) if self != base_class

        partitions = partitions(include_subpartitions: PgParty.config.include_subpartitions_in_partition_list)
        return (self.primary_key = get_primary_key(base_class.name)) if partitions.empty?

        first_partition = partitions.detect { |p| !connection.table_partitioned?(p) }
        raise 'No leaf partitions exist for this model. Create a partition to contain your data' unless first_partition

        (self.primary_key = in_partition(first_partition).get_primary_key(base_class.name))
      end

      def table_exists?
        target_table = partitions.first || table_name

        connection.schema_cache.data_source_exists?(target_table)
      end

      def partitions(**args)
        PgParty::ModelDecorator.new(self).partitions(**args)
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
