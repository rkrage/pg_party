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

      def partition_key_eq(*args)
        PgParty::ModelDecorator.new(self).partition_key_eq(*args)
      end
    end
  end
end
