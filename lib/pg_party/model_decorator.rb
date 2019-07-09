# frozen_string_literal: true

require "pg_party/cache"

module PgParty
  class ModelDecorator < SimpleDelegator
    def partition_primary_key
      if self != base_class
        base_class.primary_key
      elsif partition_name = partitions.first
        in_partition(partition_name).get_primary_key(base_class.name)
      else
        get_primary_key(base_class.name)
      end
    end

    def partition_table_exists?
      target_table = partitions.first || table_name

      connection.schema_cache.data_source_exists?(target_table)
    end

    def in_partition(child_table_name)
      PgParty::Cache.fetch_model(cache_key, child_table_name) do
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
        end
      end
    end

    def partition_key_eq(value)
      if complex_partition_key
        complex_partition_key_query("(#{partition_key}) = (?)", value)
      else
        where(current_arel_table[partition_key].eq(value))
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
        node = current_arel_table[partition_key]

        where(node.gteq(start_range).and(node.lt(end_range)))
      end
    end

    def list_partition_key_in(*values)
      if complex_partition_key
        complex_partition_key_query("(#{partition_key}) IN (?)", values.flatten)
      else
        where(current_arel_table[partition_key].in(values.flatten))
      end
    end

    def partitions
      PgParty::Cache.fetch_partitions(cache_key) do
        connection.select_values(<<-SQL)
          SELECT pg_inherits.inhrelid::regclass::text
          FROM pg_tables
          INNER JOIN pg_inherits
            ON pg_tables.tablename::regclass = pg_inherits.inhparent::regclass
          WHERE pg_tables.tablename = #{connection.quote(table_name)}
        SQL
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

    def model_class
      if respond_to?(:klass)
        klass
      else
        self
      end
    end

    def complex_partition_key_query(clause, *interpolated_values)
      subquery = model_class
        .unscoped
        .select("*")
        .where(clause, *interpolated_values)

      from(subquery, current_alias)
    end
  end
end
