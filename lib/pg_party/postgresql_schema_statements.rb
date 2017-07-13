require 'active_record/connection_adapters/postgresql_adapter'

module PgParty
  module PostgreSQLSchemaStatements
    def create_master_partition(table_name, comment: nil, **options)
      modified_options = options.except(:id, :primary_key, :range_key)
      range_key        = options.fetch(:range_key, 'created_at::date')
      id_type          = options.fetch(:id, :bigserial).to_sym
      primary_key      = _primary_key_for_partition(options[:primary_key])

      # TODO: do we need to worry about SQL injection here?
      partition_clause = "PARTITION BY RANGE ((#{range_key}))"

      td = create_table_definition(
        table_name,
        modified_options[:temporary],
        partition_clause,
        modified_options[:as],
        comment: comment
      )

      if id_type == :uuid
        td.send(id_type, primary_key, null: false, default: 'gen_random_uuid()')
      else
        td.send(id_type, primary_key, null: false)
      end

      yield td if block_given?

      if modified_options[:force]
        drop_table(table_name, **modified_options, if_exists: true)
      end

      result = execute(schema_creation.accept(td))

      if supports_comments? && !supports_comments_in_create?
        change_table_comment(table_name, comment) if comment.present?

        td.columns.each do |column|
          change_column_comment(table_name, column.name, column.comment) if column.comment.present?
        end
      end

      result
    end

    def create_child_partition(parent_table_name, start_range:, end_range:, **options)
      primary_key      = _primary_key_for_partition(options[:primary_key])
      range_key        = options.fetch(:range_key, 'created_at::date')
      child_table_name = "#{parent_table_name}_#{Digest::MD5.hexdigest(start_range.to_s + end_range.to_s)}"

      # TODO: SQL injection?
      partition_clause = <<-SQL
        PARTITION OF #{parent_table_name}
        FOR VALUES FROM (#{quote(start_range)}) TO (#{quote(end_range)})
      SQL

      result = create_table(child_table_name, id: false, options: partition_clause)

      if primary_key
        # TODO: SQL injection?
        execute(<<-SQL)
          ALTER TABLE #{child_table_name}
          ADD PRIMARY KEY (#{primary_key})
        SQL
      end

      result
    end

    def _primary_key_for_partition(primary_key)
      return if primary_key == false
      raise "composite primary keys not supported" if primary_key.is_a?(Array)

      # TODO: better primary key lookup
      primary_key || :id
    end
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:include, PgParty::PostgreSQLSchemaStatements)
