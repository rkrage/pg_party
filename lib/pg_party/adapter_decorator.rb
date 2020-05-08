# frozen_string_literal: true

require "digest"

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
      create_partition_of(table_name, range_constraint_clause(start_range, end_range), **options)
    end

    def create_list_partition_of(table_name, values:, **options)
      create_partition_of(table_name, list_constraint_clause(values), **options)
    end

    def create_table_like(table_name, new_table_name, **options)
      primary_key = options.fetch(:primary_key) { calculate_primary_key(table_name) }

      validate_primary_key(primary_key)

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
      attach_partition(parent_table_name, child_table_name, range_constraint_clause(start_range, end_range))
    end

    def attach_list_partition(parent_table_name, child_table_name, values:)
      attach_partition(parent_table_name, child_table_name, list_constraint_clause(values))
    end

    def detach_partition(parent_table_name, child_table_name)
      execute(<<-SQL)
        ALTER TABLE #{quote_table_name(parent_table_name)}
        DETACH PARTITION #{quote_table_name(child_table_name)}
      SQL

      PgParty.cache.clear!
    end

    private

    def create_partition(table_name, type, partition_key, **options)
      modified_options = options.except(:id, :primary_key, :template)
      template         = options.fetch(:template, true)
      id               = options.fetch(:id, :bigserial)
      primary_key      = options.fetch(:primary_key) { calculate_primary_key(table_name) }

      validate_primary_key(primary_key)

      modified_options[:id]      = false
      modified_options[:options] = "PARTITION BY #{type.to_s.upcase} (#{quote_partition_key(partition_key)})"

      create_table(table_name, modified_options) do |td|
        if id == :uuid
          td.column(primary_key, id, null: false, default: uuid_function)
        elsif id
          td.column(primary_key, id, null: false)
        end

        yield(td) if block_given?
      end

      # Rails 4 has a bug where uuid columns are always nullable
      change_column_null(table_name, primary_key, false) if id == :uuid

      return unless template

      create_table_like(table_name, template_table_name(table_name), primary_key: id && primary_key)
    end

    def create_partition_of(table_name, constraint_clause, **options)
      child_table_name    = options.fetch(:name) { hashed_table_name(table_name, constraint_clause) }
      primary_key         = options.fetch(:primary_key) { calculate_primary_key(table_name) }
      template_table_name = template_table_name(table_name)

      if schema_cache.data_source_exists?(template_table_name)
        create_table_like(template_table_name, child_table_name, primary_key: false)
      else
        create_table_like(table_name, child_table_name, primary_key: primary_key)
      end

      attach_partition(table_name, child_table_name, constraint_clause)

      child_table_name
    end

    def attach_partition(parent_table_name, child_table_name, constraint_clause)
      execute(<<-SQL)
        ALTER TABLE #{quote_table_name(parent_table_name)}
        ATTACH PARTITION #{quote_table_name(child_table_name)}
        FOR VALUES #{constraint_clause}
      SQL

      PgParty.cache.clear!
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

    def validate_primary_key(key)
      raise ArgumentError, "composite primary key not supported" if key.is_a?(Array)
    end

    def quote_partition_key(key)
      if key.is_a?(Proc)
        key.call.to_s # very difficult to determine how to sanitize a complex expression
      else
        Array.wrap(key).map(&method(:quote_column_name)).join(",")
      end
    end

    def quote_collection(values)
      Array.wrap(values).map(&method(:quote)).join(",")
    end

    def template_table_name(table_name)
      "#{table_name}_template"
    end

    def range_constraint_clause(start_range, end_range)
      "FROM (#{quote_collection(start_range)}) TO (#{quote_collection(end_range)})"
    end

    def list_constraint_clause(values)
      "IN (#{quote_collection(values.try(:to_a) || values)})"
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
  end
end
