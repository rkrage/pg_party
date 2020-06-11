# frozen_string_literal: true

require "pg_party/adapter_decorator"

module PgParty
  module Adapter
    module PostgreSQLMethods
      def create_range_partition(*args, **options, &blk)
        PgParty::AdapterDecorator.new(self).create_range_partition(*args, **options, &blk)
      end

      def create_list_partition(*args, **options, &blk)
        PgParty::AdapterDecorator.new(self).create_list_partition(*args, **options, &blk)
      end

      def create_range_partition_of(*args, **options)
        PgParty::AdapterDecorator.new(self).create_range_partition_of(*args, **options)
      end

      def create_list_partition_of(*args, **options)
        PgParty::AdapterDecorator.new(self).create_list_partition_of(*args, **options)
      end

      def create_table_like(*args, **options)
        PgParty::AdapterDecorator.new(self).create_table_like(*args, **options)
      end

      def attach_range_partition(*args, **options)
        PgParty::AdapterDecorator.new(self).attach_range_partition(*args, **options)
      end

      def attach_list_partition(*args, **options)
        PgParty::AdapterDecorator.new(self).attach_list_partition(*args, **options)
      end

      def detach_partition(*args, **options)
        PgParty::AdapterDecorator.new(self).detach_partition(*args, **options)
      end
    end
  end
end
