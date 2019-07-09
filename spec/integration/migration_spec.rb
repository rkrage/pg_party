# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveRecord::ConnectionAdapters::PostgreSQLAdapter do
  let(:table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:child_table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:table_like_name) { "t_#{SecureRandom.hex(6)}" }
  let(:template_table_name) { "#{table_name}_template" }
  let(:current_date) { Date.current }
  let(:start_range) { current_date }
  let(:end_range) { current_date + 1.month }
  let(:values) { (1..3) }
  let(:timestamps_block) { ->(t) { t.timestamps null: false, precision: nil } }
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
    adapter.execute("DROP TABLE IF EXISTS #{table_like_name} CASCADE")
  end

  subject(:adapter) { ActiveRecord::Base.connection }

  subject(:create_range_partition) do
    adapter.create_range_partition(
      table_name,
      partition_key: ->{ "(created_at::date)" },
      primary_key: :custom_id,
      id: :uuid,
      template: false,
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
      primary_key: :custom_id,
      start_range: start_range,
      end_range: end_range
    )
  end

  subject(:create_list_partition_of) do
    create_list_partition

    adapter.create_list_partition_of(
      table_name,
      name: child_table_name,
      values: values
    )
  end

  subject(:create_range_table_like) do
    create_range_partition_of

    adapter.create_table_like(child_table_name, table_like_name)
  end

  subject(:create_list_table_like) do
    create_list_partition_of

    adapter.create_table_like(child_table_name, table_like_name)
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

    describe "template table" do
      subject do
        create_range_partition
        PgDumpHelper.dump_table_structure(template_table_name)
      end

      it { is_expected.to be_empty }
    end
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

    describe "template table" do
      let(:create_table_sql) do
        <<-SQL
          CREATE TABLE #{template_table_name} (
            #{table_name}_id integer DEFAULT nextval('#{table_name}_#{table_name}_id_seq'::regclass) NOT NULL
          );
        SQL
      end

      let(:primary_key_sql) do
        <<-SQL
          ALTER TABLE ONLY #{template_table_name}
          ADD CONSTRAINT #{template_table_name}_pkey PRIMARY KEY (#{table_name}_id);
        SQL
      end

      subject do
        create_list_partition
        PgDumpHelper.dump_table_structure(template_table_name)
      end

      it { is_expected.to include_heredoc(create_table_sql) }
      it { is_expected.to include_heredoc(primary_key_sql) }
    end
  end

  describe "#create_range_partition_of" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE #{child_table_name} (
          custom_id uuid DEFAULT #{uuid_function} NOT NULL,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
        );
      SQL
    end

    let(:attach_table_sql) do
      <<-SQL
        ALTER TABLE ONLY #{table_name}
        ATTACH PARTITION #{child_table_name}
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

    subject do
      create_range_partition_of
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    it { is_expected.to include_heredoc(create_table_sql) }
    it { is_expected.to include_heredoc(attach_table_sql) }
    it { is_expected.to include_heredoc(primary_key_sql) }
  end

  describe "#create_list_partition_of" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE #{child_table_name} (
          #{table_name}_id integer DEFAULT nextval('#{table_name}_#{table_name}_id_seq'::regclass) NOT NULL
        );
      SQL
    end

    let(:attach_table_sql) do
      <<-SQL
        ALTER TABLE ONLY #{table_name}
        ATTACH PARTITION #{child_table_name}
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
    it { is_expected.to include_heredoc(attach_table_sql) }
    it { is_expected.to include_heredoc(primary_key_sql) }
  end

  describe "#create_table_like" do
    context "range partition" do
      let(:create_table_sql) do
        <<-SQL
          CREATE TABLE #{table_like_name} (
            custom_id uuid DEFAULT #{uuid_function} NOT NULL,
            created_at timestamp without time zone NOT NULL,
            updated_at timestamp without time zone NOT NULL
          );
        SQL
      end

      let(:primary_key_sql) do
        <<-SQL
          ALTER TABLE ONLY #{table_like_name}
          ADD CONSTRAINT #{table_like_name}_pkey
          PRIMARY KEY (custom_id);
        SQL
      end

      subject do
        create_range_table_like
        PgDumpHelper.dump_table_structure(table_like_name)
      end

      it { is_expected.to include_heredoc(create_table_sql) }
      it { is_expected.to include_heredoc(primary_key_sql) }
    end

    context "list partition" do
      let(:create_table_sql) do
        <<-SQL
          CREATE TABLE #{table_like_name} (
            #{table_name}_id integer DEFAULT nextval('#{table_name}_#{table_name}_id_seq'::regclass) NOT NULL
          );
        SQL
      end

      let(:primary_key_sql) do
        <<-SQL
          ALTER TABLE ONLY #{table_like_name}
          ADD CONSTRAINT #{table_like_name}_pkey
          PRIMARY KEY (#{table_name}_id);
        SQL
      end

      subject do
        create_list_table_like
        PgDumpHelper.dump_table_structure(table_like_name)
      end

      it { is_expected.to include_heredoc(create_table_sql) }
      it { is_expected.to include_heredoc(primary_key_sql) }
    end
  end

  describe "#attach_range_partition" do
    let(:attach_table_sql) do
      <<-SQL
        ALTER TABLE ONLY #{table_name}
        ATTACH PARTITION #{child_table_name}
        FOR VALUES FROM ('#{start_range}') TO ('#{end_range}');
      SQL
    end

    subject do
      attach_range_partition
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    it { is_expected.to include_heredoc(attach_table_sql) }
  end

  describe "#attach_list_partition" do
    let(:attach_table_sql) do
      <<-SQL
        ALTER TABLE ONLY #{table_name}
        ATTACH PARTITION #{child_table_name}
        FOR VALUES IN (1, 2, 3);
      SQL
    end

    subject do
      attach_list_partition
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    it { is_expected.to include_heredoc(attach_table_sql) }
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
    it { is_expected.to_not include("ATTACH") }
  end
end
