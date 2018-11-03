# frozen_string_literal: true

module PgParty
  class SchemaHelper
    class << self
      def table_exists?(table_name)
        schema_cache.send(table_exists_method, table_name)
      end

      private

      def table_exists_method
        [:data_source_exists?, :table_exists?].detect do |meth|
          schema_cache.respond_to?(meth)
        end
      end

      def schema_cache
        ActiveRecord::Base.connection.schema_cache
      end
    end
  end
end
