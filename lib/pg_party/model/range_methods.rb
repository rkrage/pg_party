require "pg_party/model_decorator"

module PgParty
  module Model
    module RangeMethods
      def create_partition(*args)
        PgParty::ModelDecorator.new(self).create_range_partition(*args)
      end

      def in_partition(*args)
        PgParty::ModelDecorator.new(self).in_partition(*args)
      end

      def partition_key_in(*args)
        PgParty::ModelDecorator.new(self).range_partition_key_in(*args)
      end

      def partition_key_eq(*args)
        PgParty::ModelDecorator.new(self).partition_key_eq(*args)
      end
    end
  end
end
