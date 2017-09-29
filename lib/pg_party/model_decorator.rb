module PgParty
  class ModelDecorator < SimpleDelegator
    def partition_key_eq(value)
      where(partition_key_as_arel.eq(value))
    end

    def range_partition_key_in(start_range, end_range)
      node = partition_key_as_arel

      where(node.gteq(start_range).and(node.lt(end_range)))
    end

    def list_partition_key_in(*values)
      where(partition_key_as_arel.in(values.flatten))
    end

    def create_range_partition(start_range:, end_range:, **options)
      modified_options = options.merge(
        start_range: start_range,
        end_range: end_range,
        primary_key: primary_key,
        partition_key: partition_key
      )

      connection.create_range_partition_of(table_name, **modified_options)
    end

    def create_list_partition(values:, **options)
      modified_options = options.merge(
        values: values,
        primary_key: primary_key,
        partition_key: partition_key
      )

      connection.create_list_partition_of(table_name, **modified_options)
    end

    private

    def partition_key_as_arel
      arel_column = arel_table[partition_column]

      if partition_cast
        quoted_cast = connection.quote_column_name(partition_cast)

        Arel::Nodes::NamedFunction.new("CAST", [arel_column.as(quoted_cast)])
      else
        arel_column
      end
    end
  end
end
