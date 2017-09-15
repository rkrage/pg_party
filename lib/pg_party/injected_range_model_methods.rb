require "pg_party/injected_model_methods"

module PgParty
  module InjectedRangeModelMethods
    include InjectedModelMethods

    def create_partition(start_range:, end_range:, **options)
      modified_options = options.merge(
        start_range: start_range,
        end_range: end_range,
        primary_key: primary_key,
        partition_key: partition_key
      )

      connection.create_range_partition_of(table_name, **modified_options)
    end

    def partition_key_in(start_range, end_range)
      node = partition_key_as_arel

      where(node.gteq(start_range).and(node.lt(end_range)))
    end
  end
end
