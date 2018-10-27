# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveRecord::ConnectionAdapters::PostgreSQLAdapter do
  let(:table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:child_table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:current_date) { Date.current }
  let(:start_range) { current_date }
  let(:end_range) { current_date + 1.month }
  let(:values) { [1, 2, 3] }
  let(:timestamps_block) { ->(t) { t.timestamps null: false } }
  let(:uuid_function) do
    if Rails.gem_version >= Gem::Version.new("5.1")
      "gen_random_uuid()"
    else
      "uuid_generate_v4()"
    end
  end

  before do
    ActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore
  end

  after do
    ActiveRecord::Base.primary_key_prefix_type = nil

    adapter.execute("DROP TABLE IF EXISTS #{table_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{child_table_name} CASCADE")
  end

  subject(:adapter) { ActiveRecord::Base.connection }

  subject(:create_range_partition) do
    adapter.create_range_partition(
      table_name,
      partition_key: ->{ "(created_at::date)" },
      primary_key: :custom_id,
      id: :uuid,
      &timestamps_block
    )
  end

  subject(:create_list_partition) do
    adapter.create_list_partition(
      table_name,
      partition_key: "#{table_name}_id",
      id: :serial
    )
  end

  subject(:create_range_partition_of) do
    create_range_partition

    adapter.create_range_partition_of(
      table_name,
      name: child_table_name,
      index: true,
      primary_key: :custom_id,
      partition_key: ->{ "(created_at::date)" },
      start_range: start_range,
      end_range: end_range
    )
  end

  subject(:create_list_partition_of) do
    create_list_partition

    adapter.create_list_partition_of(
      table_name,
      name: child_table_name,
      index: true,
      partition_key: "#{table_name}_id",
      values: values
    )
  end

  subject(:attach_range_partition) do
    create_range_partition

    adapter.execute("CREATE TABLE #{child_table_name} (LIKE #{table_name})")

    adapter.attach_range_partition(
      table_name,
      child_table_name,
      start_range: start_range,
      end_range: end_range
    )
  end

  subject(:attach_list_partition) do
    create_list_partition

    adapter.execute("CREATE TABLE #{child_table_name} (LIKE #{table_name})")

    adapter.attach_list_partition(
      table_name,
      child_table_name,
      values: values
    )
  end

  subject(:detach_partition) do
    create_range_partition
    create_range_partition_of

    adapter.detach_partition(table_name, child_table_name)
  end

  describe "#create_range_partition" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE #{table_name} (
          custom_id uuid DEFAULT #{uuid_function} NOT NULL,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
        ) PARTITION BY RANGE (((created_at)::date));
      SQL
    end

    subject do
      create_range_partition
      PgDumpHelper.dump_table_structure(table_name)
    end

    it { is_expected.to include_heredoc(create_table_sql) }
    it { is_expected.to_not include("SET DEFAULT nextval") }
  end

  describe "#create_list_partition" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE #{table_name} (
          #{table_name}_id integer NOT NULL
        ) PARTITION BY LIST (#{table_name}_id);
      SQL
    end

    let(:incrementing_id_sql) do
      <<-SQL
        ALTER TABLE ONLY #{table_name}
        ALTER COLUMN #{table_name}_id
        SET DEFAULT nextval('#{table_name}_#{table_name}_id_seq'::regclass);
      SQL
    end

    subject do
      create_list_partition
      PgDumpHelper.dump_table_structure(table_name)
    end

    it { is_expected.to include_heredoc(create_table_sql) }
    it { is_expected.to include_heredoc(incrementing_id_sql) }
  end

  describe "#create_range_partition_of" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE #{child_table_name}
        PARTITION OF #{table_name}
        FOR VALUES FROM ('#{start_range}') TO ('#{end_range}');
      SQL
    end

    let(:primary_key_sql) do
      <<-SQL
        ALTER TABLE ONLY #{child_table_name}
        ADD CONSTRAINT #{child_table_name}_pkey
        PRIMARY KEY (custom_id);
      SQL
    end

    let(:index_sql) do
      <<-SQL
        CREATE INDEX index_#{child_table_name}_on_partition_key
        ON #{child_table_name}
        USING btree (((created_at)::date));
      SQL
    end

    subject do
      create_range_partition_of
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    it { is_expected.to include_heredoc(create_table_sql) }
    it { is_expected.to include_heredoc(primary_key_sql) }
    it { is_expected.to include_heredoc(index_sql) }
  end

  describe "#create_list_partition_of" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE #{child_table_name}
        PARTITION OF #{table_name}
        FOR VALUES IN (1, 2, 3);
      SQL
    end

    let(:primary_key_sql) do
      <<-SQL
        ALTER TABLE ONLY #{child_table_name}
        ADD CONSTRAINT #{child_table_name}_pkey
        PRIMARY KEY (#{table_name}_id);
      SQL
    end

    subject do
      create_list_partition_of
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    it { is_expected.to include_heredoc(create_table_sql) }
    it { is_expected.to include_heredoc(primary_key_sql) }
    it { is_expected.to_not include("CREATE INDEX") }
  end

  describe "#attach_range_partition" do
    subject do
      attach_range_partition
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE #{child_table_name}
        PARTITION OF #{table_name}
        FOR VALUES FROM ('#{start_range}') TO ('#{end_range}');
      SQL
    end

    it { is_expected.to include_heredoc(create_table_sql) }
  end

  describe "#attach_list_partition" do
    subject do
      attach_list_partition
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE #{child_table_name}
        PARTITION OF #{table_name}
        FOR VALUES IN (1, 2, 3);
      SQL
    end

    it { is_expected.to include_heredoc(create_table_sql) }
  end

  describe "#detach_partition" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE #{child_table_name} (
          custom_id uuid DEFAULT #{uuid_function} NOT NULL,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
        );
      SQL
    end

    subject do
      detach_partition
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    it { is_expected.to include_heredoc(create_table_sql) }
  end
end
