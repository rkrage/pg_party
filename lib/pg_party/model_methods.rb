module PgParty
  module ModelMethods
    def range_partition_by(key)
      @partition_key = key
      @partition_column, @partition_cast = key.to_s.split("::")

      require "pg_party/injected_range_model_methods"
      extend InjectedRangeModelMethods
    end

    def list_partition_by(key)
      @partition_key = key
      @partition_column, @partition_cast = key.to_s.split("::")

      require "pg_party/injected_list_model_methods"
      extend InjectedListModelMethods
    end

    def partitioned?
      @partition_key.present?
    end
  end
end
