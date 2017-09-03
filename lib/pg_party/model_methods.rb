module PgParty
  module ModelMethods
    def range_partition_by(key)
      @partition_key = key
      @partition_column, @partition_cast = key.to_s.split("::")

      extend InjectedRangeModelMethods
    end

    def list_partition_by(key)
      @partition_key = key
      @partition_column, @partition_cast = key.to_s.split("::")

      extend InjectedListModelMethods
    end

    def partitioned?
      @partition_key.present?
    end
  end
end
