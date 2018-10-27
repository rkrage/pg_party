# frozen_string_literal: true

require "pg_party/model_decorator"

module PgParty
  module Model
    module ListMethods
      def create_partition(*args)
        PgParty::ModelDecorator.new(self).create_list_partition(*args)
      end

      def partition_key_in(*args)
        PgParty::ModelDecorator.new(self).list_partition_key_in(*args)
      end
    end
  end
end
