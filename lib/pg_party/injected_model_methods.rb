module PgParty
  module InjectedModelMethods
    attr_reader :partition_key, :partition_column, :partition_cast

    def partition_key_matching(value)
      where(partition_key_as_arel.eq(value))
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
