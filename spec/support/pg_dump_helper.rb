class PgDumpHelper
  def self.dump_table_structure(table_name)
    new(table_name: table_name).dump_table_structure
  end

  def dump_table_structure
    pg_dump.gsub("#{schema_name}.", "")
  end

  private

  def initialize(options)
    @table_name = "#{schema_name}.#{options[:table_name]}"
  end

  def pg_dump
    `#{pg_env_string} pg_dump -s -x -O -d #{config[:database]} -t #{@table_name}`
  end

  def pg_env_string
    env_strings = []
    env_strings << "PGHOST=#{config[:host]}"         if config[:host]
    env_strings << "PGPORT=#{config[:port]}"         if config[:port]
    env_strings << "PGPASSWORD=#{config[:password]}" if config[:password]
    env_strings << "PGUSER=#{config[:username]}"     if config[:username]
    env_strings.join(" ")
  end

  def config
    @config ||= ActiveRecord::Base.connection_config
  end

  def schema_name
    config[:schema_search_path]
  end
end
