# frozen_string_literal: true

class PgDumpHelper
  def self.dump_table_structure(table_name)
    new(table_name: table_name).dump_table_structure
  end

  def dump_table_structure
    pg_dump.gsub("#{schema_name}.", "")
  end

  def self.dump_indices
    ActiveRecord::Base.connection.select_values(
      "SELECT indexdef FROM pg_indexes WHERE tablename NOT LIKE 'pg%'"
    ).join("; ").gsub("#{schema_name}.", "")
  end

  private

  def initialize(options)
    @table_name = "#{schema_name}.#{options[:table_name]}"
  end

  def pg_dump
    `#{pg_env_string} pg_dump -s -x -O -d #{config[:database]} -t #{@table_name} 2>/dev/null`
  end

  def pg_env_string
    env_strings = []
    env_strings << "PGHOST=#{config[:host]}"         if config[:host]
    env_strings << "PGPORT=#{config[:port]}"         if config[:port]
    env_strings << "PGPASSWORD=#{config[:password]}" if config[:password]
    env_strings << "PGUSER=#{config[:username]}"     if config[:username]
    env_strings.join(" ")
  end

  def self.config
    @config ||= ActiveRecord::Base.connection_db_config.as_json["configuration_hash"].symbolize_keys!
  end

  def config
    self.class.config
  end

  def self.schema_name
    config[:schema_search_path]
  end

  def schema_name
    self.class.schema_name
  end
end
