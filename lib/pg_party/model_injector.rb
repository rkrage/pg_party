module PgParty
  class ModelInjector
    def initialize(model, key)
      @model = model
      @key = key

      @column, @cast = key.to_s.split("::")
    end

    def inject_range_methods
      create_class_attributes

      require "pg_party/model/range_methods"
      @model.extend(PgParty::Model::RangeMethods)
    end

    def inject_list_methods
      create_class_attributes

      require "pg_party/model/list_methods"
      @model.extend(PgParty::Model::ListMethods)
    end

    private

    def create_class_attributes
      @model.class_attribute(
        :cached_partitions,
        :partition_key,
        :partition_column,
        :partition_cast,
        instance_accessor: false
      )

      @model.partition_key = @key
      @model.partition_column = @column
      @model.partition_cast = @cast
    end
  end
end
