# frozen_string_literal: true

require "pg_party/model_decorator"

module PgParty
  module Model
    module ListMethods
      def create_partition(*args, **options)
        PgParty::ModelDecorator.new(self).create_list_partition(*args, **options)
      end

      def partition_key_in(*args, **options)
        PgParty::ModelDecorator.new(self).list_partition_key_in(*args, **options)
      end
    end
  end
end
