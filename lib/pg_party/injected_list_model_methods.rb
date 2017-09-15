require "pg_party/injected_model_methods"

module PgParty
  module InjectedListModelMethods
    include InjectedModelMethods

    def create_partition(values:, **options)
      modified_options = options.merge(
        values: values,
        primary_key: primary_key,
        partition_key: partition_key
      )

      connection.create_list_partition_of(table_name, **modified_options)
    end

    def partition_key_in(*values)
      where(partition_key_as_arel.in(values.flatten))
    end
  end
end
