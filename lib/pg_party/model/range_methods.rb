require "pg_party/model_decorator"
require "pg_party/model/shared_methods"

module PgParty
  module Model
    module RangeMethods
      include SharedMethods

      def create_partition(*args)
        PgParty::ModelDecorator.new(self).create_range_partition(*args)
      end

      def partition_key_in(*args)
        PgParty::ModelDecorator.new(self).range_partition_key_in(*args)
      end
    end
  end
end
