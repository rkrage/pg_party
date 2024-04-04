# frozen_string_literal: true

require "pg_party/adapter_decorator"

module PgParty
  module Adapter
    module PostgreSQLMethods
      ruby2_keywords def create_range_partition(*args, &blk)
        PgParty::AdapterDecorator.new(self).create_range_partition(*args, &blk)
      end

      ruby2_keywords def create_list_partition(*args, &blk)
        PgParty::AdapterDecorator.new(self).create_list_partition(*args, &blk)
      end

      ruby2_keywords def create_hash_partition(*args, &blk)
        PgParty::AdapterDecorator.new(self).create_hash_partition(*args, &blk)
      end

      ruby2_keywords def create_range_partition_of(*args)
        PgParty::AdapterDecorator.new(self).create_range_partition_of(*args)
      end

      ruby2_keywords def create_list_partition_of(*args)
        PgParty::AdapterDecorator.new(self).create_list_partition_of(*args)
      end

      ruby2_keywords def create_hash_partition_of(*args)
        PgParty::AdapterDecorator.new(self).create_hash_partition_of(*args)
      end

      ruby2_keywords def create_default_partition_of(*args)
        PgParty::AdapterDecorator.new(self).create_default_partition_of(*args)
      end

      ruby2_keywords def create_table_like(*args)
        PgParty::AdapterDecorator.new(self).create_table_like(*args)
      end

      ruby2_keywords def attach_range_partition(*args)
        PgParty::AdapterDecorator.new(self).attach_range_partition(*args)
      end

      ruby2_keywords def attach_list_partition(*args)
        PgParty::AdapterDecorator.new(self).attach_list_partition(*args)
      end

      ruby2_keywords def attach_hash_partition(*args)
        PgParty::AdapterDecorator.new(self).attach_hash_partition(*args)
      end

      ruby2_keywords def attach_default_partition(*args)
        PgParty::AdapterDecorator.new(self).attach_default_partition(*args)
      end

      ruby2_keywords def detach_partition(*args)
        PgParty::AdapterDecorator.new(self).detach_partition(*args)
      end

      ruby2_keywords def partitions_for_table_name(*args)
        PgParty::AdapterDecorator.new(self).partitions_for_table_name(*args)
      end

      ruby2_keywords def parent_for_table_name(*args)
        PgParty::AdapterDecorator.new(self).parent_for_table_name(*args)
      end

      ruby2_keywords def add_index_on_all_partitions(*args)
        PgParty::AdapterDecorator.new(self).add_index_on_all_partitions(*args)
      end

      ruby2_keywords def table_partitioned?(*args)
        PgParty::AdapterDecorator.new(self).table_partitioned?(*args)
      end
    end
  end
end
