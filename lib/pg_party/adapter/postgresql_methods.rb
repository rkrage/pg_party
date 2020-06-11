# frozen_string_literal: true

require "pg_party/adapter_decorator"
require "ruby2_keywords"

module PgParty
  module Adapter
    module PostgreSQLMethods
      ruby2_keywords def create_range_partition(*args, &blk)
        PgParty::AdapterDecorator.new(self).create_range_partition(*args, &blk)
      end

      ruby2_keywords def create_list_partition(*args, &blk)
        PgParty::AdapterDecorator.new(self).create_list_partition(*args, &blk)
      end

      ruby2_keywords def create_range_partition_of(*args)
        PgParty::AdapterDecorator.new(self).create_range_partition_of(*args)
      end

      ruby2_keywords def create_list_partition_of(*args)
        PgParty::AdapterDecorator.new(self).create_list_partition_of(*args)
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

      ruby2_keywords def detach_partition(*args)
        PgParty::AdapterDecorator.new(self).detach_partition(*args)
      end
    end
  end
end
