module PgParty
  module Adapter
    module AbstractMethods
      def create_range_partition(*)
        raise NotImplementedError, "#create_range_partition is not implemented"
      end

      def create_list_partition(*)
        raise NotImplementedError, "#create_list_partition is not implemented"
      end

      def create_range_partition_of(*)
        raise NotImplementedError, "#create_range_partition_of is not implemented"
      end

      def create_list_partition_of(*)
        raise NotImplementedError, "#create_list_partition_of is not implemented"
      end

      def attach_range_partition(*)
        raise NotImplementedError, "#attach_range_partition is not implemented"
      end

      def attach_list_partition(*)
        raise NotImplementedError, "#attach_list_partition is not implemented"
      end

      def detach_partition(*)
        raise NotImplementedError, "#detach_partition is not implemented"
      end
    end
  end
end
