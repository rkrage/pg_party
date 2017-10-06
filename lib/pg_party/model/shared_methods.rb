module PgParty
  module Model
    module SharedMethods
      def partitions
        PgParty::ModelDecorator.new(self).partitions
      end

      def create_partition(*args)
        PgParty::ModelDecorator.new(self).create_list_partition(*args)
      end

      def in_partition(*args)
        PgParty::ModelDecorator.new(self).in_partition(*args)
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
