# frozen_string_literal: true

module PgParty
  module Hacks
    module SchemaCache
      def self.included(base)
        return if base.method_defined?(:data_source_exists?)

        base.send(:alias_method, :data_source_exists?, :table_exists?)
      end
    end
  end
end
