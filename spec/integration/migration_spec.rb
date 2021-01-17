# frozen_string_literal: true

require "spec_helper"

# These specs run on all Postgres versions
RSpec.describe ActiveRecord::ConnectionAdapters::PostgreSQLAdapter do
  let(:table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:child_table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:sibling_table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:grandchild_table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:table_like_name) { "t_#{SecureRandom.hex(6)}" }
  let(:template_table_name) { "#{table_name}_template" }
  let(:current_date) { Date.current }
  let(:start_range) { current_date }
  let(:end_range) { current_date + 1.month }
  let(:values) { (1..3) }
  let(:uuid_values) { [SecureRandom.uuid, SecureRandom.uuid] }
  let(:timestamps_block) { ->(t) { t.timestamps null: false, precision: nil } }
  let(:index_prefix) { "i_#{SecureRandom.hex(6)}" }
  let(:index_threads) { nil }
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
    adapter.execute("DROP TABLE IF EXISTS #{sibling_table_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{grandchild_table_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{table_like_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{template_table_name} CASCADE")
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

  subject(:create_range_partition_of_subpartitioned_by_list) do
    adapter.create_range_partition(
      table_name,
      partition_key: ->{ "(created_at::date)" },
      primary_key: :custom_id,
      id: :uuid,
      &timestamps_block
    )

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

  subject(:add_index_on_all_partitions) do
    create_range_partition_of_subpartitioned_by_list

    adapter.add_index_on_all_partitions table_name, :updated_at, name: index_prefix, using: :hash,
                                        in_threads: index_threads, algorithm: :concurrently,
                                        where: "created_at > '#{current_date.to_time.iso8601}'"
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

      context 'when config.create_template_tables = false' do
        before { PgParty.config.create_template_tables = false }
        after { PgParty.config.create_template_tables = true }

        it { is_expected.not_to include_heredoc(create_table_sql) }
        it { is_expected.not_to include_heredoc(primary_key_sql) }
      end
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

    context 'when subpartitioning' do
      let(:create_table_sql) do
        <<-SQL
          CREATE TABLE #{child_table_name} (
            custom_id uuid DEFAULT #{uuid_function} NOT NULL,
            created_at timestamp without time zone NOT NULL,
            updated_at timestamp without time zone NOT NULL
          )
          PARTITION BY LIST (custom_id);
        SQL
      end

      subject do
        create_range_partition_of_subpartitioned_by_list
        PgDumpHelper.dump_table_structure(child_table_name)
      end

      it { is_expected.to include_heredoc(create_table_sql) }
      it { is_expected.to include_heredoc(attach_table_sql) }
      it { is_expected.not_to include_heredoc(primary_key_sql) }
    end

    context 'when an unsupported partition_type: is specified' do
      subject(:create_range_partition_of) do
        create_range_partition

        adapter.create_range_partition_of(
          table_name,
          name: child_table_name,
          partition_type: :something_invalid,
          partition_key: :custom_id,
          start_range: start_range,
          end_range: end_range,
        )
      end

      it 'raises ArgumentError' do
        expect { subject }.to raise_error ArgumentError, 'Supported partition types are range, list, hash'
      end
    end

    context 'when partition_type: is specified but not partition_key:' do
      subject(:create_range_partition_of) do
        create_range_partition

        adapter.create_range_partition_of(
          table_name,
          name: child_table_name,
          partition_type: :list,
          start_range: start_range,
          end_range: end_range,
        )
      end

      it 'raises ArgumentError' do
        expect { subject }.to raise_error ArgumentError, '`partition_key` is required when specifying a partition_type'
      end
    end
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

  describe '#parent_for_table_name' do
    let(:traverse) { false }

    before { create_range_partition_of_subpartitioned_by_list }

    it 'fetches the parent of the given table' do
      expect(adapter.parent_for_table_name(grandchild_table_name)).to eq child_table_name
      expect(adapter.parent_for_table_name(child_table_name)).to eq table_name
      expect(adapter.parent_for_table_name(table_name)).to be_nil
    end

    context 'when traverse: true argument is specified' do
      it 'returns top-level ancestor' do
        expect(adapter.parent_for_table_name(grandchild_table_name, traverse: true)).to eq table_name
        expect(adapter.parent_for_table_name(child_table_name, traverse: true)).to eq table_name
        expect(adapter.parent_for_table_name(table_name, traverse: true)).to be_nil
      end
    end
  end

  describe '#partitions_for_table_name' do
    let(:traverse) { false }

    before do
      create_range_partition_of_subpartitioned_by_list
    end

    context 'when include_subpartitions: false' do
      it 'fetches the partitions of the table specified' do
        expect(adapter.partitions_for_table_name(table_name, include_subpartitions: false)).to eq(
          [child_table_name, sibling_table_name]
        )
        expect(adapter.partitions_for_table_name(child_table_name, include_subpartitions: false)).to eq(
          [grandchild_table_name]
        )
        expect(adapter.partitions_for_table_name(grandchild_table_name, include_subpartitions: false)).to be_empty
      end
    end

    context 'when include_subpartitions: true' do
      it 'fetches all partitions and subpartitions of the table specified' do
        expect(adapter.partitions_for_table_name(table_name, include_subpartitions: true)).to eq(
          [child_table_name, grandchild_table_name, sibling_table_name]
        )
        expect(adapter.partitions_for_table_name(child_table_name, include_subpartitions: true)).to eq(
          [grandchild_table_name]
        )
        expect(adapter.partitions_for_table_name(grandchild_table_name, include_subpartitions: true)).to be_empty
      end
    end
  end

  describe "#add_index_on_all_partitions" do
    let(:grandchild_index_sql) do
      <<-SQL
        CREATE INDEX #{index_prefix}_#{Digest::MD5.hexdigest(grandchild_table_name)[0..6]}
        ON #{grandchild_table_name} USING hash (updated_at)
        WHERE (created_at > '#{current_date} 00:00:00'::timestamp without time zone)
      SQL
    end
    let(:sibling_index_sql) do
      <<-SQL
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

    it 'creates the indices using CONCURRENTLY directive because `algorthim: :concurrently` args are present' do
      subject
      expect(adapter).to have_received(:execute).with(
        "CREATE  INDEX CONCURRENTLY \"#{index_prefix}_#{Digest::MD5.hexdigest(grandchild_table_name)[0..6]}\" "\
        "ON \"#{grandchild_table_name}\" USING hash (\"updated_at\") "\
        "WHERE created_at > '#{current_date.to_time.iso8601}'"
      )
      expect(adapter).to have_received(:execute).with(
        "CREATE  INDEX CONCURRENTLY \"#{index_prefix}_#{Digest::MD5.hexdigest(sibling_table_name)[0..6]}\" "\
        "ON \"#{sibling_table_name}\" USING hash (\"updated_at\") "\
        "WHERE created_at > '#{current_date.to_time.iso8601}'"
      )
    end

    context 'when unique: true index option is used' do
      subject(:add_index_on_all_partitions) do
        create_list_partition_of

        adapter.add_index_on_all_partitions table_name, "#{table_name}_id", name: index_prefix,
                                            in_threads: index_threads, algorithm: :concurrently, unique: true
      end

      it 'creates a unique index' do
        subject
        expect(adapter).to have_received(:execute).with(
          "CREATE UNIQUE INDEX CONCURRENTLY \"#{index_prefix}_#{Digest::MD5.hexdigest(child_table_name)[0..6]}\" "\
        "ON \"#{child_table_name}\"  (\"#{table_name}_id\")"
        )
      end
    end

    context 'when in_threads: is provided' do
      let(:index_threads) { ActiveRecord::Base.connection_pool.size - 1 }

      before do
        allow(Parallel).to receive(:map).with([child_table_name, sibling_table_name], in_threads: index_threads)
                             .and_yield(child_table_name).and_yield(sibling_table_name)
      end

      it 'calls through Parallel.map' do
        subject
        expect(Parallel).to have_received(:map)
                              .with([child_table_name, sibling_table_name], in_threads: index_threads)
      end

      it { is_expected.to include_heredoc(sibling_index_sql) }
      it { is_expected.to include_heredoc(grandchild_index_sql) }

      context 'when in a transaction' do
        it 'raises ArgumentError' do
          ActiveRecord::Base.transaction do
            expect { subject }.to raise_error(ArgumentError,
              '`in_threads:` cannot be used within a transaction. If running in a migration, use '\
              '`disable_ddl_transaction!` and break out this operation into its own migration.'
            )
          end
        end
      end

      context 'when in_threads is equal to or greater than connection pool size' do
        let(:index_threads) { ActiveRecord::Base.connection_pool.size }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error(ArgumentError,
            'in_threads: must be lower than your database connection pool size'
          )
        end
      end
    end
  end

  describe '#table_partitioned?' do
    before { create_range_partition_of_subpartitioned_by_list }

    it 'returns true for partitioned tables; false for partitions themselves' do
      expect(adapter.table_partitioned?(table_name)).to be true
      expect(adapter.table_partitioned?(child_table_name)).to be true
      expect(adapter.table_partitioned?(sibling_table_name)).to be false
      expect(adapter.table_partitioned?(grandchild_table_name)).to be false
    end
  end
end
