# frozen_string_literal: true

module PgParty
  module Adapter
    module AbstractMethods
      def create_range_partition(*)
        raise "#create_range_partition is not implemented"
      end

      def create_list_partition(*)
        raise "#create_list_partition is not implemented"
      end

      def create_hash_partition(*)
        raise "#create_hash_partition is not implemented"
      end

      def create_range_partition_of(*)
        raise "#create_range_partition_of is not implemented"
      end

      def create_list_partition_of(*)
        raise "#create_list_partition_of is not implemented"
      end

      def create_hash_partition_of(*)
        raise "#create_hash_partition_of is not implemented"
      end

      def create_default_partition_of(*)
        raise "#create_default_partition_of is not implemented"
      end

      def create_table_like(*)
        raise "#create_table_like is not implemented"
      end

      def attach_range_partition(*)
        raise "#attach_range_partition is not implemented"
      end

      def attach_list_partition(*)
        raise "#attach_list_partition is not implemented"
      end

      def attach_hash_partition(*)
        raise "#attach_hash_partition is not implemented"
      end

      def attach_default_partition(*)
        raise "#attach_default_partition is not implemented"
      end

      def detach_partition(*)
        raise "#detach_partition is not implemented"
      end

      def parent_for_table_name(*)
        raise "#parent_for_table_name is not implemented"
      end

      def partitions_for_table_name(*)
        raise "#partitions_for_table_name is not implemented"
      end

      def add_index_on_all_partitions(*)
        raise "#add_index_on_all_partitions is not implemented"
      end
    end
  end
end
