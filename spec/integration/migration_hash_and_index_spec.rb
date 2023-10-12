# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveRecord::ConnectionAdapters::PostgreSQLAdapter do
  let(:table_name) { "t1_#{SecureRandom.hex(6)}" }
  let(:child_table_name) { "t2_#{SecureRandom.hex(6)}" }
  let(:sibling_table_name) { "t3_#{SecureRandom.hex(6)}" }
  let(:grandchild_table_name) { "t4_#{SecureRandom.hex(6)}" }
  let(:table_like_name) { "t_#{SecureRandom.hex(6)}" }
  let(:template_table_name) { "#{table_name}_template" }
  let(:current_date) { Date.current }
  let(:start_range) { current_date }
  let(:end_range) { current_date + 1.month }
  let(:index_prefix) { "i_#{SecureRandom.hex(6)}" }
  let(:uuid_values) { [SecureRandom.uuid, SecureRandom.uuid] }
  let(:create_with_primary_key) { false }

  before do
    ActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore
  end

  after do
    ActiveRecord::Base.primary_key_prefix_type = nil

    adapter.execute("DROP TABLE IF EXISTS #{table_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{child_table_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{sibling_table_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{grandchild_table_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{table_like_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{template_table_name} CASCADE")
  end

  subject(:adapter) { ActiveRecord::Base.connection }

  subject(:create_hash_partition) do
    adapter.create_hash_partition(
      table_name,
      partition_key: "#{table_name}_id",
      create_with_primary_key: create_with_primary_key,
      id: :serial
    ) do |t|
      t.timestamps null: false, precision: nil
    end
  end

  subject(:create_hash_partition_of) do
    create_hash_partition

    adapter.create_hash_partition_of(
      table_name,
      name: child_table_name,
      modulus: 2,
      remainder: 0
    )
  end

  subject(:create_default_partition_of) do
    create_hash_partition

    adapter.create_default_partition_of(
      table_name,
      name: child_table_name
    )
  end

  subject(:create_hash_table_like) do
    create_hash_partition_of

    adapter.create_table_like(child_table_name, table_like_name)
  end

  subject(:attach_hash_partition) do
    create_hash_partition

    adapter.execute("CREATE TABLE #{child_table_name} (LIKE #{table_name})")

    adapter.attach_hash_partition(
      table_name,
      child_table_name,
      modulus: 2,
      remainder: 1
    )
  end

  subject(:attach_default_partition) do
    adapter.create_list_partition(
      table_name,
      partition_key: "#{table_name}_id",
      id: :serial
    )

    adapter.execute("CREATE TABLE #{child_table_name} (LIKE #{table_name})")

    adapter.attach_default_partition(
      table_name,
      child_table_name
    )
  end

  subject(:create_range_partition_of_subpartitioned_by_list) do
    adapter.create_range_partition(
      table_name,
      partition_key: -> { "(created_at::date)" },
      primary_key: :custom_id,
      id: :uuid
    ) do |t|
      t.timestamps null: false, precision: nil
    end

    adapter.create_range_partition_of(
      table_name,
      name: child_table_name,
      primary_key: :custom_id,
      start_range: start_range,
      end_range: end_range,
      partition_type: :list,
      partition_key: :custom_id
    )

    adapter.create_list_partition_of(
      child_table_name,
      name: grandchild_table_name,
      values: uuid_values
    )

    adapter.create_range_partition_of(
      table_name,
      name: sibling_table_name,
      primary_key: :custom_id,
      start_range: end_range,
      end_range: end_range + 1.month
    )
  end

  subject(:add_index_on_all_partitions) do
    create_range_partition_of_subpartitioned_by_list

    adapter.add_index_on_all_partitions(
      table_name,
      :updated_at,
      name: index_prefix,
      using: :hash,
      algorithm: :concurrently,
      where: "created_at > '#{current_date.to_time.iso8601}'"
    )
  end

  describe "#create_hash_partition" do
    let(:create_table_sql) do
      <<~SQL
        CREATE TABLE #{table_name} (
          #{table_name}_id integer NOT NULL,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
        ) PARTITION BY HASH (#{table_name}_id);
      SQL
    end

    let(:incrementing_id_sql) do
      <<~SQL
        ALTER TABLE ONLY #{table_name}
        ALTER COLUMN #{table_name}_id
        SET DEFAULT nextval('#{table_name}_#{table_name}_id_seq'::regclass);
      SQL
    end

    let(:primary_key_sql) do
      <<~SQL
          ALTER TABLE ONLY #{table_name}
          ADD CONSTRAINT #{table_name}_pkey PRIMARY KEY (#{table_name}_id);
      SQL
    end

    subject do
      create_hash_partition
      PgDumpHelper.dump_table_structure(table_name)
    end

    it { is_expected.to include_heredoc(create_table_sql) }
    it { is_expected.to include_heredoc(incrementing_id_sql) }
    it { is_expected.not_to include_heredoc(primary_key_sql) }

    describe "template table" do
      let(:create_table_sql) do
        <<~SQL
          CREATE TABLE #{template_table_name} (
            #{table_name}_id integer DEFAULT nextval('#{table_name}_#{table_name}_id_seq'::regclass) NOT NULL,
            created_at timestamp without time zone NOT NULL,
            updated_at timestamp without time zone NOT NULL
          );
        SQL
      end

      let(:primary_key_sql) do
        <<~SQL
          ALTER TABLE ONLY #{template_table_name}
          ADD CONSTRAINT #{template_table_name}_pkey PRIMARY KEY (#{table_name}_id);
        SQL
      end

      subject do
        create_hash_partition
        PgDumpHelper.dump_table_structure(template_table_name)
      end

      it { is_expected.to include_heredoc(create_table_sql) }
      it { is_expected.to include_heredoc(primary_key_sql) }

      context "when config.create_template_tables = false" do
        before { PgParty.config.create_template_tables = false }
        after { PgParty.config.create_template_tables = true }

        it { is_expected.not_to include_heredoc(create_table_sql) }
        it { is_expected.not_to include_heredoc(primary_key_sql) }
      end
    end

    context "when config.create_with_primary_key = true" do
      before { PgParty.config.create_with_primary_key = true }
      after { PgParty.config.create_with_primary_key = false }

      context "when create_with_primary_key: false argument is provided" do
        it { is_expected.to include_heredoc(create_table_sql) }
        it { is_expected.to include_heredoc(incrementing_id_sql) }
        it { is_expected.not_to include_heredoc(primary_key_sql) }
      end

      context "when create_with_primary_key: argument is not provided" do
        subject do
          adapter.create_hash_partition(
            table_name,
            partition_key: "#{table_name}_id",
            id: :serial
          ) do |t|
            t.timestamps null: false, precision: nil
          end

          PgDumpHelper.dump_table_structure(table_name)
        end

        it { is_expected.to include_heredoc(create_table_sql) }
        it { is_expected.to include_heredoc(incrementing_id_sql) }
        it { is_expected.to include_heredoc(primary_key_sql) }
      end
    end

    context "when create_with_primary_key: true argument is provided" do
      let(:create_with_primary_key) { true }

      it { is_expected.to include_heredoc(create_table_sql) }
      it { is_expected.to include_heredoc(incrementing_id_sql) }
      it { is_expected.to include_heredoc(primary_key_sql) }
    end
  end

  describe "#create_hash_partition_of" do
    let(:create_table_sql) do
      <<~SQL
        CREATE TABLE #{child_table_name} (
          #{table_name}_id integer DEFAULT
          nextval('#{table_name}_#{table_name}_id_seq'::regclass) NOT NULL,
          created_at timestamp without time zone NOT NULL,
          updated_at timestamp without time zone NOT NULL
        );
      SQL
    end

    let(:attach_table_sql) do
      <<~SQL
        ALTER TABLE ONLY #{table_name}
        ATTACH PARTITION #{child_table_name}
        FOR VALUES WITH (modulus 2, remainder 0);
      SQL
    end

    let(:primary_key_sql) do
      <<~SQL
        ALTER TABLE ONLY #{child_table_name}
        ADD CONSTRAINT #{child_table_name}_pkey
        PRIMARY KEY (#{table_name}_id);
      SQL
    end

    subject do
      create_hash_partition_of
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    it { is_expected.to include_heredoc(create_table_sql) }
    it { is_expected.to include_heredoc(attach_table_sql) }
    it { is_expected.to include_heredoc(primary_key_sql) }

    context "when config.create_with_primary_key = true" do
      before { PgParty.config.create_with_primary_key = true }
      after { PgParty.config.create_with_primary_key = false }

      it { is_expected.to include_heredoc(create_table_sql) }
      it { is_expected.to include_heredoc(attach_table_sql) }
      it { is_expected.to include_heredoc(primary_key_sql) }

      context "when config.create_template_tables = false" do
        before { PgParty.config.create_template_tables = false }
        after { PgParty.config.create_template_tables = true }

        it { is_expected.to include_heredoc(create_table_sql) }
        it { is_expected.to include_heredoc(attach_table_sql) }
        it { is_expected.to include_heredoc(primary_key_sql) }
      end
    end
  end

  describe "#create_table_like" do
    context "hash partition" do
      let(:create_table_sql) do
        <<~SQL
          CREATE TABLE #{table_like_name} (
            #{table_name}_id integer DEFAULT nextval('#{table_name}_#{table_name}_id_seq'::regclass) NOT NULL,
            created_at timestamp without time zone NOT NULL,
            updated_at timestamp without time zone NOT NULL
          );
        SQL
      end

      let(:primary_key_sql) do
        <<~SQL
          ALTER TABLE ONLY #{table_like_name}
          ADD CONSTRAINT #{table_like_name}_pkey
          PRIMARY KEY (#{table_name}_id);
        SQL
      end

      subject do
        create_hash_table_like
        PgDumpHelper.dump_table_structure(table_like_name)
      end

      it { is_expected.to include_heredoc(create_table_sql) }
      it { is_expected.to include_heredoc(primary_key_sql) }
    end
  end

  describe "#attach_hash_partition" do
    let(:attach_table_sql) do
      <<~SQL
        ALTER TABLE ONLY #{table_name}
        ATTACH PARTITION #{child_table_name}
        FOR VALUES WITH (modulus 2, remainder 1);
      SQL
    end

    subject do
      attach_hash_partition
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    it { is_expected.to include_heredoc(attach_table_sql) }
  end

  describe "#attach_default_partition" do
    let(:attach_table_sql) do
      <<~SQL
        ALTER TABLE ONLY #{table_name}
        ATTACH PARTITION #{child_table_name}
        DEFAULT;
      SQL
    end

    subject do
      attach_default_partition
      PgDumpHelper.dump_table_structure(child_table_name)
    end

    it { is_expected.to include_heredoc(attach_table_sql) }
  end

  describe "#add_index_on_all_partitions" do
    let(:grandchild_index_sql) do
      <<~SQL
        CREATE INDEX #{index_prefix}_#{Digest::MD5.hexdigest(grandchild_table_name)[0..6]}
        ON #{grandchild_table_name} USING hash (updated_at)
        WHERE (created_at > '#{current_date} 00:00:00'::timestamp without time zone)
      SQL
    end
    let(:sibling_index_sql) do
      <<~SQL
        CREATE INDEX #{index_prefix}_#{Digest::MD5.hexdigest(sibling_table_name)[0..6]}
        ON #{sibling_table_name} USING hash (updated_at)
        WHERE (created_at > '#{current_date} 00:00:00'::timestamp without time zone)
      SQL
    end

    before { allow(adapter).to receive(:execute).and_call_original }

    subject do
      add_index_on_all_partitions
      PgDumpHelper.dump_indices
    end

    it { is_expected.to include_heredoc(sibling_index_sql) }
    it { is_expected.to include_heredoc(grandchild_index_sql) }

    it "creates the indices using CONCURRENTLY directive because `algorthim: :concurrently` args are present" do
      subject
      expect(adapter).to have_received(:execute).with(
        "CREATE  INDEX CONCURRENTLY \"#{index_prefix}_#{Digest::MD5.hexdigest(grandchild_table_name)[0..6]}\" " \
        "ON \"#{grandchild_table_name}\" USING hash (\"updated_at\") " \
        "WHERE created_at > '#{current_date.to_time.iso8601}'"
      )
      expect(adapter).to have_received(:execute).with(
        "CREATE  INDEX CONCURRENTLY \"#{index_prefix}_#{Digest::MD5.hexdigest(sibling_table_name)[0..6]}\" " \
        "ON \"#{sibling_table_name}\" USING hash (\"updated_at\") " \
        "WHERE created_at > '#{current_date.to_time.iso8601}'"
      )
    end

    it "creates indices, non-concurrently, on partitioned tables using ON ONLY directive" do
      subject
      expect(adapter).to have_received(:execute).with(
        "CREATE  INDEX \"#{index_prefix}\" " \
        "ON ONLY \"#{table_name}\" USING hash (\"updated_at\") " \
        "WHERE created_at > '#{current_date.to_time.iso8601}'"
      )
      expect(adapter).to have_received(:execute).with(
        "CREATE  INDEX \"#{index_prefix}_#{Digest::MD5.hexdigest(child_table_name)[0..6]}\" " \
        "ON ONLY \"#{child_table_name}\" USING hash (\"updated_at\") " \
        "WHERE created_at > '#{current_date.to_time.iso8601}'"
      )
    end

    it "attaches the partitioned indices to the correct parent table indices" do
      subject
      expect(adapter).to have_received(:execute).with(
        "ALTER INDEX \"#{index_prefix}\" ATTACH PARTITION " \
        "\"#{index_prefix}_#{Digest::MD5.hexdigest(child_table_name)[0..6]}\""
      )
      expect(adapter).to have_received(:execute).with(
        "ALTER INDEX \"#{index_prefix}\" ATTACH PARTITION " \
        "\"#{index_prefix}_#{Digest::MD5.hexdigest(sibling_table_name)[0..6]}\""
      )
      expect(adapter).to have_received(:execute).with(
        "ALTER INDEX \"#{index_prefix}_#{Digest::MD5.hexdigest(child_table_name)[0..6]}\" ATTACH PARTITION " \
        "\"#{index_prefix}_#{Digest::MD5.hexdigest(grandchild_table_name)[0..6]}\""
      )
    end

    context "when an index is not valid at the end of the operation" do
      let(:index_dump) { PgDumpHelper.dump_indices }

      before do
        # Simulate failure to attach a child index
        allow(adapter).to receive(:execute).with(
          "ALTER INDEX \"#{index_prefix}\" ATTACH PARTITION " \
          "\"#{index_prefix}_#{Digest::MD5.hexdigest(sibling_table_name)[0..6]}\""
        )
      end

      it "raises error, after dropping any indices created in the operation" do
        expect { add_index_on_all_partitions }.to raise_error "index creation failed - an index was marked invalid"
        expect(index_dump).not_to include_heredoc(sibling_index_sql)
        expect(index_dump).not_to include_heredoc(grandchild_index_sql)
        expect(adapter).to have_received(:execute).with(
          %(DROP INDEX IF EXISTS "#{index_prefix}")
        )
        expect(adapter).to have_received(:execute).with(
          %(DROP INDEX IF EXISTS "#{index_prefix}_#{Digest::MD5.hexdigest(sibling_table_name)[0..6]}")
        )
        expect(adapter).to have_received(:execute).with(
          %(DROP INDEX IF EXISTS "#{index_prefix}_#{Digest::MD5.hexdigest(child_table_name)[0..6]}")
        )
        expect(adapter).to have_received(:execute).with(
          %(DROP INDEX IF EXISTS "#{index_prefix}_#{Digest::MD5.hexdigest(grandchild_table_name)[0..6]}")
        )
      end
    end
  end
end
