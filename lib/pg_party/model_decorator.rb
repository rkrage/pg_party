# frozen_string_literal: true

module PgParty
  class ModelDecorator < SimpleDelegator
    def in_partition(child_table_name)
      PgParty.cache.fetch_model(cache_key, child_table_name) do
        Class.new(__getobj__) do
          self.table_name = child_table_name

          # to avoid argument errors when calling model_name
          def self.name
            superclass.name
          end

          # when returning records from a query, Rails
          # allocates objects first, then initializes
          def self.allocate
            superclass.allocate
          end

          # creating and persisting new records from a child partition
          # will ultimately insert into the parent partition table
          def self.new(*args, &blk)
            superclass.new(*args, &blk)
          end

          # to avoid unnecessary db lookups
          def self.partitions
            []
          end
        end
      end
    end

    def partition_key_eq(value)
      if complex_partition_key
        complex_partition_key_query("(#{partition_key}) = (?)", value)
      else
        where_partition_key(:eq, value)
      end
    end

    def range_partition_key_in(start_range, end_range)
      if complex_partition_key
        complex_partition_key_query(
          "(#{partition_key}) >= (?) AND (#{partition_key}) < (?)",
          start_range,
          end_range
        )
      else
        where_partition_key(:gteq, start_range).merge(
          where_partition_key(:lt, end_range)
        )
      end
    end

    def list_partition_key_in(*values)
      if complex_partition_key
        complex_partition_key_query("(#{partition_key}) IN (?)", values.flatten)
      else
        where(current_arel_table[partition_key].in(values.flatten))
      end
    end

    alias_method :hash_partition_key_in, :list_partition_key_in

    def partitions(include_subpartitions: PgParty.config.include_subpartitions_in_partition_list)
      PgParty.cache.fetch_partitions(cache_key, include_subpartitions) do
        connection.partitions_for_table_name(table_name, include_subpartitions: include_subpartitions)
      end
    rescue
      []
    end

    def create_range_partition(start_range:, end_range:, **options)
      modified_options = options.merge(
        start_range: start_range,
        end_range: end_range,
        primary_key: primary_key,
      )

      create_partition(:create_range_partition_of, table_name, **modified_options)
    end

    def create_list_partition(values:, **options)
      modified_options = options.merge(
        values: values,
        primary_key: primary_key,
      )

      create_partition(:create_list_partition_of, table_name, **modified_options)
    end

    def create_hash_partition(modulus:, remainder:, **options)
      modified_options = options.merge(
        modulus: modulus,
        remainder: remainder,
        primary_key: primary_key,
      )

      create_partition(:create_hash_partition_of, table_name, **modified_options)
    end

    def create_default_partition(**options)
      modified_options = options.merge(
        primary_key: primary_key,
      )
      create_partition(:create_default_partition_of, table_name, **modified_options)
    end

    private

    def create_partition(migration_method, table_name, **options)
      transaction { connection.send(migration_method, table_name, **options) }
    end

    def cache_key
      __getobj__.object_id
    end

    # https://stackoverflow.com/questions/28685149/activerecord-query-with-aliasd-table-names
    def current_arel_table
      none.arel.source.left.tap do |node|
        if [Arel::Table, Arel::Nodes::TableAlias].exclude?(node.class)
          raise "could not find arel table in current scope"
        end
      end
    end

    def current_alias
      arel_node = current_arel_table

      case arel_node
      when Arel::Table
        arel_node.name
      when Arel::Nodes::TableAlias
        arel_node.right
      end
    end

    def complex_partition_key_query(clause, *interpolated_values)
      subquery = unscoped
        .select("*")
        .where(clause, *interpolated_values)

      from(subquery, current_alias)
    end

    def where_partition_key(meth, values)
      partition_key_array = Array.wrap(partition_key)
      values = Array.wrap(values)

      if partition_key_array.size != values.size
        raise "number of provided values does not match the number of partition key columns"
      end

      arel_query = partition_key_array.zip(values).inject(nil) do |obj, (column, value)|
        node = current_arel_table[column].send(meth, value)

        if obj.nil?
          node
        else
          obj.and(node)
        end
      end

      where(arel_query)
    end
  end
end
