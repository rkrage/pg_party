module PgParty
  class ModelInjector
    def initialize(model, key)
      @model = model
      @key = key
    end

    def inject_range_methods
      require "pg_party/model/range_methods"

      inject_methods_for(PgParty::Model::RangeMethods)
    end

    def inject_list_methods
      require "pg_party/model/list_methods"

      inject_methods_for(PgParty::Model::ListMethods)
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

      if @key.is_a?(Proc)
        @model.partition_key = @key.call
        @model.complex_partition_key = true
      else
        @model.partition_key = @key
        @model.complex_partition_key = false
      end
    end
  end
end
