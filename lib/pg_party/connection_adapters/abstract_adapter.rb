module PgParty
  module ConnectionAdapters
    module AbstractAdapter
      def create_range_partition(*args)
        raise NotImplementedError, "#create_range_partition is not implemented"
      end

      def create_list_partition(*args)
        raise NotImplementedError, "#create_list_partition is not implemented"
      end

      def create_range_partition_of(*args)
        raise NotImplementedError, "#create_range_partition_of is not implemented"
      end

      def create_list_partition_of(*args)
        raise NotImplementedError, "#create_list_partition_of is not implemented"
      end

      def attach_range_partition(*args)
        raise NotImplementedError, "#attach_range_partition is not implemented"
      end

      def attach_list_partition(*args)
        raise NotImplementedError, "#attach_list_partition is not implemented"
      end

      def detach_partition(*args)
        raise NotImplementedError, "#detach_partition is not implemented"
      end
    end
  end
end
