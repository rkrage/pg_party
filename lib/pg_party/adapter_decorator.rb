# frozen_string_literal: true

require "digest"
require 'parallel'

module PgParty
  class AdapterDecorator < SimpleDelegator
    SUPPORTED_PARTITION_TYPES = %i[range list hash].freeze

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

    def create_hash_partition(table_name, partition_key:, **options, &blk)
      create_partition(table_name, :hash, partition_key, **options, &blk)
    end

    def create_range_partition_of(table_name, start_range:, end_range:, **options)
      create_partition_of(table_name, range_constraint_clause(start_range, end_range), **options)
    end

    def create_list_partition_of(table_name, values:, **options)
      create_partition_of(table_name, list_constraint_clause(values), **options)
    end

    def create_hash_partition_of(table_name, modulus:, remainder:, **options)
      create_partition_of(table_name, hash_constraint_clause(modulus, remainder), **options)
    end

    def create_default_partition_of(table_name, **options)
      create_partition_of(table_name, nil, default_partition: true, **options)
    end

    def create_table_like(table_name, new_table_name, **options)
      primary_key           = options.fetch(:primary_key) { calculate_primary_key(table_name) }
      partition_key         = options.fetch(:partition_key, nil)
      partition_type        = options.fetch(:partition_type, nil)
      create_with_pks       = options.fetch(
                                :create_with_primary_key,
                                PgParty.config.create_with_primary_key
                              )

      validate_primary_key(primary_key) unless create_with_pks
      if partition_type
        validate_supported_partition_type!(partition_type)
        raise ArgumentError, '`partition_key` is required when specifying a partition_type' unless partition_key
      end

      like_option = if !partition_type || create_with_pks
                      'INCLUDING ALL'
                    else
                      'INCLUDING ALL EXCLUDING INDEXES'
                    end

      execute(<<-SQL)
        CREATE TABLE #{quote_table_name(new_table_name)} (
          LIKE #{quote_table_name(table_name)} #{like_option}
        ) #{partition_type ? partition_by_clause(partition_type, partition_key) : nil}
      SQL

      return if partition_type
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

    def attach_hash_partition(parent_table_name, child_table_name, modulus:, remainder:)
      attach_partition(parent_table_name, child_table_name, hash_constraint_clause(modulus, remainder))
    end

    def attach_default_partition(parent_table_name, child_table_name)
      execute(<<-SQL)
        ALTER TABLE #{quote_table_name(parent_table_name)}
        ATTACH PARTITION #{quote_table_name(child_table_name)}
        DEFAULT
      SQL

      PgParty.cache.clear!
    end

    def detach_partition(parent_table_name, child_table_name)
      execute(<<-SQL)
        ALTER TABLE #{quote_table_name(parent_table_name)}
        DETACH PARTITION #{quote_table_name(child_table_name)}
      SQL

      PgParty.cache.clear!
    end

    def partitions_for_table_name(table_name, include_subpartitions:, _accumulator: [])
      select_values(%[
          SELECT pg_inherits.inhrelid::regclass::text
          FROM pg_tables
          INNER JOIN pg_inherits
            ON pg_tables.tablename::regclass = pg_inherits.inhparent::regclass
          WHERE pg_tables.schemaname = current_schema() AND
          pg_tables.tablename = #{quote(table_name)}
                    ]).each_with_object(_accumulator) do |partition, acc|
        acc << partition
        next unless include_subpartitions

        partitions_for_table_name(partition, include_subpartitions: true, _accumulator: acc)
      end
    end

    def parent_for_table_name(table_name, traverse: false)
      parent = select_values(%[
          SELECT pg_inherits.inhparent::regclass::text
          FROM pg_tables
          INNER JOIN pg_inherits
            ON pg_tables.tablename::regclass = pg_inherits.inhrelid::regclass
          WHERE pg_tables.schemaname = current_schema() AND
          pg_tables.tablename = #{quote(table_name)}
      ]).first
      return parent if parent.nil? || !traverse

      while (parents_parent = parent_for_table_name(parent)) do
        parent = parents_parent
      end

      parent
    end

    def add_index_on_all_partitions(table_name, column_name, in_threads: nil, **options)
      if in_threads && open_transactions > 0
        raise ArgumentError, '`in_threads:` cannot be used within a transaction. If running in a migration, use '\
              '`disable_ddl_transaction!` and break out this operation into its own migration.'
      end

      index_name, index_type, index_columns, index_options, algorithm, using = extract_index_options(
        add_index_options(table_name, column_name, **options)
      )

      # Postgres limits index name to 63 bytes (characters). We will use 8 characters for a `_random_suffix`
      # on partitions to ensure no conflicts, leaving 55 chars for the specified index name
      raise ArgumentError 'index name is too long - must be 55 characters or fewer' if index_name.length > 55

      recursive_add_index(
        table_name: table_name,
        index_name: index_name,
        index_type: index_type,
        index_columns: index_columns,
        index_options: index_options,
        algorithm: algorithm,
        using: using,
        in_threads: in_threads
      )
    end

    def table_partitioned?(table_name)
      select_values(%[
        SELECT relkind FROM pg_catalog.pg_class AS c
        JOIN pg_catalog.pg_namespace AS ns ON c.relnamespace = ns.oid
        WHERE relname = #{quote(table_name)} AND nspname = current_schema()
      ]).first == 'p'
    end

    private

    def create_partition(table_name, type, partition_key, **options)
      modified_options      = options.except(:id, :primary_key, :template, :create_with_primary_key)
      template              = options.fetch(:template, PgParty.config.create_template_tables)
      id                    = options.fetch(:id, :bigserial)
      primary_key           = options.fetch(:primary_key) { calculate_primary_key(table_name) }
      create_with_pks       = options.fetch(
                                :create_with_primary_key,
                                PgParty.config.create_with_primary_key
                              )

      validate_supported_partition_type!(type)

      if create_with_pks
        modified_options[:primary_key] = primary_key
        modified_options[:id] = id
      else
        validate_primary_key(primary_key)
        modified_options[:id] = false
      end
      modified_options[:options] = partition_by_clause(type, partition_key)

      create_table(table_name, **modified_options) do |td|
        if !modified_options[:id] && id == :uuid
          td.column(primary_key, id, null: false, default: uuid_function)
        elsif !modified_options[:id] && id
          td.column(primary_key, id, null: false)
        end

        yield(td) if block_given?
      end

      # Rails 4 has a bug where uuid columns are always nullable
      change_column_null(table_name, primary_key, false) if !modified_options[:id] && id == :uuid

      return unless template

      create_table_like(
        table_name,
        template_table_name(table_name),
        primary_key: id && primary_key,
        create_with_primary_key: create_with_pks
      )
    end

    def create_partition_of(table_name, constraint_clause, **options)
      child_table_name    = options.fetch(:name) { hashed_table_name(table_name, constraint_clause) }
      primary_key         = options.fetch(:primary_key) { calculate_primary_key(table_name) }
      template_table_name = template_table_name(table_name)

      validate_default_partition_support! if options[:default_partition]

      if schema_cache.data_source_exists?(template_table_name)
        create_table_like(template_table_name, child_table_name, primary_key: false,
                          partition_type: options[:partition_type], partition_key: options[:partition_key])
      else
        create_table_like(table_name, child_table_name, primary_key: primary_key,
                          partition_type: options[:partition_type], partition_key: options[:partition_key])
      end

      if options[:default_partition]
        attach_default_partition(table_name, child_table_name)
      else
        attach_partition(table_name, child_table_name, constraint_clause)
      end

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

    def recursive_add_index(table_name:, index_name:, index_type:, index_columns:, index_options:, using:, algorithm:,
                            in_threads: nil, _parent_index_name: nil, _created_index_names: [])
      partitions = partitions_for_table_name(table_name, include_subpartitions: false)
      updated_name = _created_index_names.empty? ? index_name : generate_index_name(index_name, table_name)

      # If this is a partitioned table, add index ONLY on this table.
      if table_partitioned?(table_name)
        add_index_only(table_name, type: index_type, name: updated_name, using: using, columns: index_columns,
                       options: index_options)
        _created_index_names << updated_name

        parallel_map(partitions, in_threads: in_threads) do |partition_name|
          recursive_add_index(
            table_name: partition_name,
            index_name: index_name,
            index_type: index_type,
            index_columns: index_columns,
            index_options: index_options,
            using: using,
            algorithm: algorithm,
            _parent_index_name: updated_name,
            _created_index_names: _created_index_names
          )
        end
      else
        _created_index_names << updated_name # Track as created before execution of concurrent index command
        add_index_from_options(table_name, name: updated_name, type: index_type, algorithm: algorithm, using: using,
                               columns: index_columns, options: index_options)
      end

      attach_child_index(updated_name, _parent_index_name) if _parent_index_name

      return true if index_valid?(updated_name)

      raise 'index creation failed - an index was marked invalid'
    rescue => e
      # Clean up any indexes created so this command can be retried later
      drop_indices_if_exist(_created_index_names)
      raise e
    end

    def attach_child_index(child, parent)
      return unless postgres_major_version >= 11

      execute "ALTER INDEX #{quote_column_name(parent)} ATTACH PARTITION #{quote_column_name(child)}"
    end

    def add_index_only(table_name, type:, name:, using:, columns:, options:)
      return unless postgres_major_version >= 11

      execute "CREATE #{type} INDEX #{quote_column_name(name)} ON ONLY "\
              "#{quote_table_name(table_name)} #{using} (#{columns})#{options}"
    end

    def add_index_from_options(table_name, name:, type:, algorithm:, using:, columns:, options:)
      execute "CREATE #{type} INDEX #{algorithm} #{quote_column_name(name)} ON "\
              "#{quote_table_name(table_name)} #{using} (#{columns})#{options}"
    end

    def extract_index_options(add_index_options_result)
      # Rails 6.1 changes the result of #add_index_options
      index_definition = add_index_options_result.first
      return add_index_options_result unless index_definition.is_a?(ActiveRecord::ConnectionAdapters::IndexDefinition)

      index_columns = if index_definition.columns.is_a?(String)
                        index_definition.columns
                      else
                        quoted_columns_for_index(index_definition.columns, index_definition.column_options)
                      end

      [
        index_definition.name,
        index_definition.unique ? 'UNIQUE' : index_definition.type,
        index_columns,
        index_definition.where ? " WHERE #{index_definition.where}" : nil,
        add_index_options_result.second, # algorithm option
        index_definition.using ? "USING #{index_definition.using}" : nil
      ]
    end

    def drop_indices_if_exist(index_names)
      index_names.uniq.each { |name| execute "DROP INDEX IF EXISTS #{quote_column_name(name)}" }
    end

    def parallel_map(arr, in_threads:)
      return [] if arr.empty?
      return arr.map { |item| yield(item) } unless in_threads && in_threads > 1

      if ActiveRecord::Base.connection_pool.size <= in_threads
        raise ArgumentError, 'in_threads: must be lower than your database connection pool size'
      end

      Parallel.map(arr, in_threads: in_threads) do |item|
        ActiveRecord::Base.connection_pool.with_connection { yield(item) }
      end
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
      "#{parent_for_table_name(table_name, traverse: true) || table_name}_template"
    end

    def range_constraint_clause(start_range, end_range)
      "FROM (#{quote_collection(start_range)}) TO (#{quote_collection(end_range)})"
    end

    def hash_constraint_clause(modulus, remainder)
      "WITH (MODULUS #{modulus.to_i}, REMAINDER #{remainder.to_i})"
    end

    def list_constraint_clause(values)
      "IN (#{quote_collection(values.try(:to_a) || values)})"
    end

    def partition_by_clause(type, partition_key)
      "PARTITION BY #{type.to_s.upcase} (#{quote_partition_key(partition_key)})"
    end

    def uuid_function
      try(:supports_pgcrypto_uuid?) ? "gen_random_uuid()" : "uuid_generate_v4()"
    end

    def hashed_table_name(table_name, key)
      return "#{table_name}_#{Digest::MD5.hexdigest(key)[0..6]}" if key

      # use _default suffix for default partitions (without a constraint clause)
      "#{table_name}_default"
    end

    def index_valid?(index_name)
      select_values(
        "SELECT relname FROM pg_class, pg_index WHERE pg_index.indisvalid = false AND "\
          "pg_index.indexrelid = pg_class.oid AND relname = #{quote(index_name)}"
      ).empty?
    end

    def generate_index_name(index_name, table_name)
      "#{index_name}_#{Digest::MD5.hexdigest(table_name)[0..6]}"
    end

    def validate_supported_partition_type!(partition_type)
      if (sym = partition_type.to_s.downcase.to_sym) && sym.in?(SUPPORTED_PARTITION_TYPES)
        return if sym != :hash || postgres_major_version >= 11

        raise NotImplementedError, 'Hash partitions are only available in Postgres 11 or higher'
      end

      raise ArgumentError, "Supported partition types are #{SUPPORTED_PARTITION_TYPES.join(', ')}"
    end

    def validate_default_partition_support!
      return if postgres_major_version >= 11

      raise NotImplementedError, 'Default partitions are only available in Postgres 11 or higher'
    end

    def supports_partitions?
      postgres_major_version >= 10
    end

    def postgres_major_version
      __getobj__.send(:postgresql_version)/10000
    end
  end
end
