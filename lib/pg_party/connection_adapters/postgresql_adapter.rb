module PgParty
  module ConnectionAdapters
    module PostgreSQLAdapter
      def create_master_partition(table_name, **options)
        modified_options = options.except(:id, :primary_key, :range_key)
        range_key        = options.fetch(:range_key, "created_at::date")
        id_type          = options.fetch(:id, :bigserial)
        primary_key      = _primary_key_for_partition(options[:primary_key])

        modified_options[:id]      = false
        modified_options[:options] = "PARTITION BY RANGE ((#{range_key}))"

        create_table(table_name, modified_options) do |td|
          if id_type == :uuid
            td.send(id_type, primary_key, null: false, default: _uuid_function)
          elsif id_type
            td.send(id_type, primary_key, null: false)
          end

          yield(td) if block_given?
        end
      end

      def create_child_partition(parent_table_name, start_range:, end_range:, **options)
        primary_key      = _primary_key_for_partition(options[:primary_key])
        range_key        = options.fetch(:range_key, "created_at::date")
        child_table_name = "#{parent_table_name}_#{Digest::MD5.hexdigest(start_range.to_s + end_range.to_s)}"

        partition_clause = <<-SQL
          PARTITION OF #{quote_table_name(parent_table_name)}
          FOR VALUES FROM (#{quote(start_range)}) TO (#{quote(end_range)})
        SQL

        create_table(child_table_name, id: false, options: partition_clause)

        if primary_key
          execute(<<-SQL)
            ALTER TABLE #{quote_table_name(child_table_name)}
            ADD PRIMARY KEY (#{quote_column_name(primary_key)})
          SQL
        end

        child_table_name
      end

      def _primary_key_for_partition(primary_key)
        return if primary_key == false
        raise "composite primary keys not supported" if primary_key.is_a?(Array)

        # TODO: better primary key lookup for existing tables
        primary_key || :id
      end

      def _uuid_function
        try(:supports_pgcrypto_uuid?) ? "gen_random_uuid()" : "uuid_generate_v4()"
      end
    end
  end
end
