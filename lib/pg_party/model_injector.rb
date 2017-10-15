module PgParty
  class ModelInjector
    def initialize(model, key)
      @model = model
      @key = key

      @column, @cast = key.to_s.split("::")
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
        :partition_column,
        :partition_cast,
        instance_accessor: false,
        instance_predicate: false
      )

      @model.partition_key = @key
      @model.partition_column = @column
      @model.partition_cast = @cast
    end
  end
end
