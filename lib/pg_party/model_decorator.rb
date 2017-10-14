module PgParty
  class ModelDecorator < SimpleDelegator
    def partition_primary_key
      if self != base_class
        base_class.primary_key
      elsif partition = partitions.first
        child_class(partition).get_primary_key(base_class.name)
      else
        get_primary_key(base_class.name)
      end
    end

    def partition_table_exists?
      target_table = partitions.first || table_name

      connection.schema_cache.send(table_exists_method, target_table)
    end

    def in_partition(table_name)
      child_class(table_name).all
    end

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

    def partitions
      connection.select_values(<<-SQL)
        SELECT pg_inherits.inhrelid::regclass::text
        FROM pg_tables
        INNER JOIN pg_inherits
          ON pg_tables.tablename::regclass = pg_inherits.inhparent::regclass
        WHERE pg_tables.tablename = #{connection.quote(table_name)}
      SQL
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

    def table_exists_method
      [:data_source_exists?, :table_exists?].detect do |meth|
        connection.schema_cache.respond_to?(meth)
      end
    end

    def child_class(table_name)
      Class.new(__getobj__) do
        self.table_name = table_name

        # when returning records from a query, Rails
        # allocates objects first, then initializes
        def self.allocate
          superclass.allocate
        end

        # not sure if this will ever get called,
        # but probably a good idea to have
        def self.new(*args, &blk)
          superclass.new(*args, &blk)
        end
      end
    end

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
