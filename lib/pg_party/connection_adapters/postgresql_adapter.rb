require "digest"

module PgParty
  module ConnectionAdapters
    module PostgreSQLAdapter
      def create_range_partition(table_name, partition_key:, **options, &blk)
        create_partition(table_name, :range, partition_key, **options, &blk)
      end

      def create_list_partition(table_name, partition_key:, **options, &blk)
        create_partition(table_name, :list, partition_key, **options, &blk)
      end

      def create_range_partition_of(table_name, start_range:, end_range:, **options)
        if options[:name]
          child_table_name = name
        else
          child_table_name = hashed_table_name(table_name, "#{start_range}#{end_range}")
        end

        constraint_clause = "FROM (#{quote(start_range)}) TO (#{quote(end_range)})"

        create_partition_of(table_name, child_table_name, constraint_clause, **options)
      end

      def create_list_partition_of(table_name, values:, **options)
        if options[:name]
          child_table_name = name
        else
          child_table_name = hashed_table_name(table_name, values.to_s)
        end

        constraint_clause = "IN (#{Array.wrap(values).map(&method(:quote)).join(",")})"

        create_partition_of(table_name, child_table_name, constraint_clause, **options)
      end

      def attach_range_partition(parent_table_name, child_table_name, start_range:, end_range:)
        execute(<<-SQL)
          ALTER TABLE #{quote_table_name(parent_table_name)}
          ATTACH PARTITION #{quote_table_name(child_table_name)}
          FOR VALUES FROM (#{quote(start_range)}) TO (#{quote(end_range)})
        SQL
      end

      def attach_list_partition(parent_table_name, child_table_name, values:)
        execute(<<-SQL)
          ALTER TABLE #{quote_table_name(parent_table_name)}
          ATTACH PARTITION #{quote_table_name(child_table_name)}
          FOR VALUES IN (#{Array.wrap(values).map(&method(:quote)).join(",")})
        SQL
      end

      def detach_partition(parent_table_name, child_table_name)
        execute(<<-SQL)
          ALTER TABLE #{quote_table_name(parent_table_name)}
          DETACH PARTITION #{quote_table_name(child_table_name)}
        SQL
      end

      private

      def create_partition(table_name, type, partition_key, **options)
        modified_options = options.except(:id, :primary_key)
        id               = options.fetch(:id, :bigserial)
        primary_key      = options.fetch(:primary_key, :id)

        raise ArgumentError, "composite primary key not supported" if primary_key.is_a?(Array)

        modified_options[:id]      = false
        modified_options[:options] = "PARTITION BY #{type.to_s.upcase} ((#{quote_partition_key(partition_key)}))"

        create_table(table_name, modified_options) do |td|
          if id == :uuid
            td.send(id, primary_key, null: false, default: uuid_function)
          elsif id
            td.send(id, primary_key, null: false)
          end

          yield td if block_given?
        end
      end

      def create_partition_of(table_name, child_table_name, constraint_clause, **options)
        primary_key   = options.fetch(:primary_key, :id)
        index         = options.fetch(:index, true)
        partition_key = options[:partition_key]

        raise ArgumentError, "composite primary key not supported" if primary_key.is_a?(Array)

        partition_clause = <<-SQL
          PARTITION OF #{quote_table_name(table_name)}
          FOR VALUES #{constraint_clause}
        SQL

        create_table(child_table_name, id: false, options: partition_clause)

        if primary_key
          execute(<<-SQL)
            ALTER TABLE #{quote_table_name(child_table_name)}
            ADD PRIMARY KEY (#{quote_column_name(primary_key)})
          SQL
        end

        if index && partition_key && primary_key != partition_key
          add_index(child_table_name, "((#{quote_partition_key(partition_key)}))")
        end

        child_table_name
      end

      def quote_partition_key(key)
        key.to_s.split("::").map(&method(:quote_column_name)).join("::")
      end

      def uuid_function
        try(:supports_pgcrypto_uuid?) ? "gen_random_uuid()" : "uuid_generate_v4()"
      end

      def hashed_table_name(table_name, key)
        "#{table_name}_#{Digest::MD5.hexdigest(key)[0..6]}"
      end
    end
  end
end
