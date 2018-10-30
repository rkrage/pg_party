# frozen_string_literal: true

require "digest"
require "pg_party/cache"

module PgParty
  class AdapterDecorator < SimpleDelegator
    def initialize(adapter)
      super(adapter)

      raise "Partitioning only supported in PostgreSQL >= 10.0" unless supports_partitions?
    end

    def create_range_partition(table_name, partition_key:, **options, &blk)
      create_partition(table_name, :range, partition_key, **options, &blk)
    end

    def create_list_partition(table_name, partition_key:, **options, &blk)
      create_partition(table_name, :list, partition_key, **options, &blk)
    end

    def create_range_partition_of(table_name, start_range:, end_range:, **options)
      constraint_clause = "FROM (#{quote_collection(start_range)}) TO (#{quote_collection(end_range)})"

      create_partition_of(table_name, constraint_clause, **options)
    end

    def create_list_partition_of(table_name, values:, **options)
      constraint_clause = "IN (#{quote_collection(values)})"

      create_partition_of(table_name, constraint_clause, **options)
    end

    def create_table_like(table_name, new_table_name, **options)
      primary_key = options.fetch(:primary_key) { calculate_primary_key(table_name) }

      execute(<<-SQL)
        CREATE TABLE #{quote_table_name(new_table_name)} (
          LIKE #{quote_table_name(table_name)} INCLUDING ALL
        )
      SQL

      return if !primary_key
      return if has_primary_key?(new_table_name)

      execute(<<-SQL)
        ALTER TABLE #{quote_table_name(new_table_name)}
        ADD PRIMARY KEY (#{quote_column_name(primary_key)})
      SQL
    end

    def attach_range_partition(parent_table_name, child_table_name, start_range:, end_range:)
      execute(<<-SQL)
        ALTER TABLE #{quote_table_name(parent_table_name)}
        ATTACH PARTITION #{quote_table_name(child_table_name)}
        FOR VALUES FROM (#{quote_collection(start_range)}) TO (#{quote_collection(end_range)})
      SQL

      PgParty::Cache.clear!
    end

    def attach_list_partition(parent_table_name, child_table_name, values:)
      execute(<<-SQL)
        ALTER TABLE #{quote_table_name(parent_table_name)}
        ATTACH PARTITION #{quote_table_name(child_table_name)}
        FOR VALUES IN (#{quote_collection(values)})
      SQL

      PgParty::Cache.clear!
    end

    def detach_partition(parent_table_name, child_table_name)
      execute(<<-SQL)
        ALTER TABLE #{quote_table_name(parent_table_name)}
        DETACH PARTITION #{quote_table_name(child_table_name)}
      SQL

      PgParty::Cache.clear!
    end

    private

    def create_partition(table_name, type, partition_key, **options)
      modified_options = options.except(:id, :primary_key)
      id               = options.fetch(:id, :bigserial)
      primary_key      = options.fetch(:primary_key) { calculate_primary_key(table_name) }

      raise ArgumentError, "composite primary key not supported" if primary_key.is_a?(Array)

      modified_options[:id]      = false
      modified_options[:options] = "PARTITION BY #{type.to_s.upcase} (#{quote_partition_key(partition_key)})"

      result = create_table(table_name, modified_options) do |td|
        if id == :uuid
          td.column(primary_key, id, null: false, default: uuid_function)
        elsif id
          td.column(primary_key, id, null: false)
        end

        yield(td) if block_given?
      end

      # Rails 4 has a bug where uuid columns are always nullable
      change_column_null(table_name, primary_key, false) if id == :uuid

      result
    end

    def create_partition_of(table_name, constraint_clause, **options)
      primary_key      = options.fetch(:primary_key) { calculate_primary_key(table_name) }
      child_table_name = options.fetch(:name) { hashed_table_name(table_name, constraint_clause) }
      index            = options.fetch(:index, true)
      partition_key    = options[:partition_key]

      raise ArgumentError, "composite primary key not supported" if primary_key.is_a?(Array)

      quoted_primary_key = quote_column_name(primary_key) if primary_key
      quoted_partition_key = quote_partition_key(partition_key) if partition_key

      execute(<<-SQL)
        CREATE TABLE #{quote_table_name(child_table_name)}
        PARTITION OF #{quote_table_name(table_name)}
        FOR VALUES #{constraint_clause}
      SQL

      if primary_key
        execute(<<-SQL)
          ALTER TABLE #{quote_table_name(child_table_name)}
          ADD PRIMARY KEY (#{quoted_primary_key})
        SQL
      end

      if index && quoted_partition_key && quoted_partition_key != quoted_primary_key
        execute(<<-SQL)
          CREATE INDEX #{quote_table_name(index_name(child_table_name))}
          ON #{quote_table_name(child_table_name)}
          USING btree (#{quoted_partition_key})
        SQL
      end

      PgParty::Cache.clear!

      child_table_name
    end

    # Rails 5.2 now returns boolean literals
    # This causes partition creation to fail when the constraint clause includes a boolean
    # Might be a PostgreSQL bug, but for now let's revert to the old quoting behavior
    def quote(value)
      case value
      when true then "'t'"
      when false then "'f'"
      else
        __getobj__.quote(value)
      end
    end

    def has_primary_key?(table_name)
      primary_key(table_name).present?
    end

    def calculate_primary_key(table_name)
      ActiveRecord::Base.get_primary_key(table_name.to_s.singularize).to_sym
    end

    def quote_partition_key(key)
      if key.is_a?(Proc)
        key.call.to_s # very difficult to determine how to sanitize a complex expression
      else
        quote_column_name(key)
      end
    end

    def quote_collection(values)
      Array.wrap(values).map(&method(:quote)).join(",")
    end

    def uuid_function
      try(:supports_pgcrypto_uuid?) ? "gen_random_uuid()" : "uuid_generate_v4()"
    end

    def hashed_table_name(table_name, key)
      "#{table_name}_#{Digest::MD5.hexdigest(key)[0..6]}"
    end

    def supports_partitions?
      __getobj__.send(:postgresql_version) >= 100000
    end

    def index_name(table_name)
      "index_#{table_name}_on_partition_key"
    end
  end
end
