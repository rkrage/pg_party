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

      def create_range_partition_of(*)
        raise "#create_range_partition_of is not implemented"
      end

      def create_list_partition_of(*)
        raise "#create_list_partition_of is not implemented"
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

      def detach_partition(*)
        raise "#detach_partition is not implemented"
      end
    end
  end
end
