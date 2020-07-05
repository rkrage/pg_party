# frozen_string_literal: true

module PgParty
  class ModelInjector
    def initialize(model, *key, &blk)
      @model = model
      @key = key.flatten.compact
      @key_blk = blk
    end

    def inject_range_methods
      require "pg_party/model/range_methods"

      inject_methods_for(PgParty::Model::RangeMethods)
    end

    def inject_list_methods
      require "pg_party/model/list_methods"

      inject_methods_for(PgParty::Model::ListMethods)
    end

    def inject_hash_methods
      require "pg_party/model/hash_methods"

      inject_methods_for(PgParty::Model::HashMethods)
    end

    private

    def inject_methods_for(mod)
      require "pg_party/model/shared_methods"

      @model.extend(PgParty::Model::SharedMethods)
      @model.extend(mod)

      create_class_attributes
    end

    def create_class_attributes
      @model.class_attribute(
        :partition_key,
        :complex_partition_key,
        instance_accessor: false,
        instance_predicate: false
      )

      if @key_blk
        @model.partition_key = @key_blk.call
        @model.complex_partition_key = true
      else
        if @key.size == 1
          @model.partition_key = @key.first
        else
          @model.partition_key = @key
        end

        @model.complex_partition_key = false
      end
    end
  end
end
