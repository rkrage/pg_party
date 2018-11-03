# frozen_string_literal: true

require "pg_party/cache"
require "pg_party/schema_helper"

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

      PgParty::SchemaHelper.table_exists?(target_table)
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
      partition_key_check_for(:partition_key_eq)

      where(partition_key_as_arel.eq(value))
    end

    def range_partition_key_in(start_range, end_range)
      partition_key_check_for(:partition_key_in)

      node = partition_key_as_arel

      where(node.gteq(start_range).and(node.lt(end_range)))
    end

    def list_partition_key_in(*values)
      partition_key_check_for(:partition_key_in)

      where(partition_key_as_arel.in(values.flatten))
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

    def partition_key_check_for(name)
      raise "##{name} not available for complex partition keys" if complex_partition_key
    end

    def cache_key
      __getobj__.object_id
    end

    def partition_key_as_arel
      arel_table[partition_key]
    end
  end
end
