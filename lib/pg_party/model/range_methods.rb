# frozen_string_literal: true

require "pg_party/model_decorator"

module PgParty
  module Model
    module RangeMethods
      def create_partition(*args, **options)
        PgParty::ModelDecorator.new(self).create_range_partition(*args, **options)
      end

      def partition_key_in(*args, **options)
        PgParty::ModelDecorator.new(self).range_partition_key_in(*args, **options)
      end
    end
  end
end
