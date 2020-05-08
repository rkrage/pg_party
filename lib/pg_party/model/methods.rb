# frozen_string_literal: true

require "pg_party/model_injector"

module PgParty
  module Model
    module Methods
      def range_partition_by(*key, &blk)
        PgParty::ModelInjector.new(self, *key, &blk).inject_range_methods
      end

      def list_partition_by(*key, &blk)
        PgParty::ModelInjector.new(self, *key, &blk).inject_list_methods
      end

      def partitioned?
        try(:partition_key).present?
      end
    end
  end
end
