# frozen_string_literal: true

require "pg_party/adapter_decorator"

module PgParty
  module Adapter
    module PostgreSQLMethods
      def create_range_partition(*args, &blk)
        PgParty::AdapterDecorator.new(self).create_range_partition(*args, &blk)
      end

      def create_list_partition(*args, &blk)
        PgParty::AdapterDecorator.new(self).create_list_partition(*args, &blk)
      end

      def create_range_partition_of(*args)
        PgParty::AdapterDecorator.new(self).create_range_partition_of(*args)
      end

      def create_list_partition_of(*args)
        PgParty::AdapterDecorator.new(self).create_list_partition_of(*args)
      end

      def create_table_like(*args)
        PgParty::AdapterDecorator.new(self).create_table_like(*args)
      end

      def attach_range_partition(*args)
        PgParty::AdapterDecorator.new(self).attach_range_partition(*args)
      end

      def attach_list_partition(*args)
        PgParty::AdapterDecorator.new(self).attach_list_partition(*args)
      end

      def detach_partition(*args)
        PgParty::AdapterDecorator.new(self).detach_partition(*args)
      end
    end
  end
end
