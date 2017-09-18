require "spec_helper"

RSpec.describe PgParty::AdapterDecorator do
  let(:adapter) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }
  let(:table_definition) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition) }
  let(:pg_version) { 100000 }
  let(:expected_uuid_function) do
    if adapter.respond_to?(:supports_pgcrypto_uuid?)
      "gen_random_uuid()"
    else
      "uuid_generate_v4()"
    end
  end

  before do
    allow(adapter).to receive(:postgresql_version).and_return(pg_version)
    allow(adapter).to receive(:execute)
    allow(adapter).to receive(:quote_table_name) { |name| "\"#{name}\"" }
    allow(adapter).to receive(:quote_column_name) { |name| "\"#{name}\"" }
    allow(adapter).to receive(:quote) { |value| "'#{value}'" }
    allow(adapter).to receive(:add_index)

    if adapter.respond_to?(:supports_pgcrypto_uuid?)
      allow(adapter).to receive(:supports_pgcrypto_uuid?).and_return(true)
    end

    allow(table_definition).to receive(:bigserial)
    allow(table_definition).to receive(:serial)
    allow(table_definition).to receive(:uuid)
    allow(table_definition).to receive(:integer)
    allow(table_definition).to receive(:timestamps)
  end

  subject(:decorator) { described_class.new(adapter) }

  describe ".initialize" do
    subject { decorator }

    context "when pg version >= 10" do
      it { is_expected.to be_a(PgParty::AdapterDecorator) }
    end

    context "when pg version < 10" do
      let(:pg_version) { 90400 }

      it "raises version error" do
        expect { subject }.to raise_error("Partitioning only supported in PostgreSQL >= 10.0")
      end
    end
  end

  describe "#create_range_partition" do
    before { allow(adapter).to receive(:create_table).and_yield(table_definition) }

    context "with default primary key" do
      subject { decorator.create_range_partition(:table_name, partition_key: :id) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY RANGE ((\"id\"))"
        )

        subject
      end

      it "calls bigserial on table definition" do
        expect(table_definition).to receive(:bigserial).with(:id, null: false)
        subject
      end
    end

    context "with composite primary key" do
      subject { decorator.create_range_partition(:table_name, partition_key: :id, primary_key: [:id, :id2]) }

      it "raise argument error" do
        expect { subject }.to raise_error(ArgumentError, "composite primary key not supported")
      end
    end

    context "with serial primary key" do
      subject { decorator.create_range_partition(:table_name, partition_key: :id, id: :serial) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY RANGE ((\"id\"))"
        )

        subject
      end

      it "calls serial on table definition" do
        expect(table_definition).to receive(:serial).with(:id, null: false)
        subject
      end
    end

    context "with uuid primary key" do
      subject { decorator.create_range_partition(:table_name, partition_key: :id, id: :uuid) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY RANGE ((\"id\"))"
        )

        subject
      end

      it "calls uuid on table definition" do
        expect(table_definition).to receive(:uuid).with(
          :id,
          null: false,
          default: expected_uuid_function
        )

        subject
      end
    end

    context "without primary key" do
      subject do
        decorator.create_range_partition(:table_name, partition_key: :some_column, id: false) do |t|
          t.integer :some_column, null: false
        end
      end

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY RANGE ((\"some_column\"))"
        )

        subject
      end

      it "does not call bigserial on table definition" do
        expect(table_definition).to_not receive(:bigserial)
        subject
      end

      it "calls integer on table definition" do
        expect(table_definition).to receive(:integer).with(:some_column, null: false)
        subject
      end
    end

    context "with custom primary key name" do
      subject { decorator.create_range_partition(:table_name, partition_key: :uid, primary_key: :uid) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY RANGE ((\"uid\"))"
        )

        subject
      end

      it "calls bigserial on table definition" do
        expect(table_definition).to receive(:bigserial).with(:uid, null: false)
        subject
      end
    end

    context "with casted partition key" do
      subject do
        decorator.create_range_partition(:table_name, partition_key: "created_at::date") do |t|
          t.timestamps
        end
      end

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY RANGE ((\"created_at\"::\"date\"))"
        )

        subject
      end

      it "calls bigserial on table definition" do
        expect(table_definition).to receive(:bigserial).with(:id, null: false)
        subject
      end

      it "calls timestamps on table definition" do
        expect(table_definition).to receive(:timestamps).with(no_args)
        subject
      end
    end
  end

  describe "#create_list_partition" do
    before { allow(adapter).to receive(:create_table).and_yield(table_definition) }

    context "with default primary key" do
      subject { decorator.create_list_partition(:table_name, partition_key: :id) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY LIST ((\"id\"))"
        )

        subject
      end

      it "calls bigserial on table definition" do
        expect(table_definition).to receive(:bigserial).with(:id, null: false)
        subject
      end
    end

    context "with composite primary key" do
      subject { decorator.create_list_partition(:table_name, partition_key: :id, primary_key: [:id, :id2]) }

      it "raise argument error" do
        expect { subject }.to raise_error(ArgumentError, "composite primary key not supported")
      end
    end

    context "with serial primary key" do
      subject { decorator.create_list_partition(:table_name, partition_key: :id, id: :serial) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY LIST ((\"id\"))"
        )

        subject
      end

      it "calls serial on table definition" do
        expect(table_definition).to receive(:serial).with(:id, null: false)
        subject
      end
    end

    context "with uuid primary key" do
      subject { decorator.create_list_partition(:table_name, partition_key: :id, id: :uuid) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY LIST ((\"id\"))"
        )

        subject
      end

      it "calls uuid on table definition" do
        expect(table_definition).to receive(:uuid).with(
          :id,
          null: false,
          default: expected_uuid_function
        )

        subject
      end
    end

    context "without primary key" do
      subject do
        decorator.create_list_partition(:table_name, partition_key: :some_column, id: false) do |t|
          t.integer :some_column, null: false
        end
      end

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY LIST ((\"some_column\"))"
        )

        subject
      end

      it "does not call bigserial on table definition" do
        expect(table_definition).to_not receive(:bigserial)
        subject
      end

      it "calls integer on table definition" do
        expect(table_definition).to receive(:integer).with(:some_column, null: false)
        subject
      end
    end

    context "with custom primary key name" do
      subject { decorator.create_list_partition(:table_name, partition_key: :uid, primary_key: :uid) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY LIST ((\"uid\"))"
        )

        subject
      end

      it "calls bigserial on table definition" do
        expect(table_definition).to receive(:bigserial).with(:uid, null: false)
        subject
      end
    end

    context "with casted partition key" do
      subject do
        decorator.create_list_partition(:table_name, partition_key: "created_at::date") do |t|
          t.timestamps
        end
      end

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY LIST ((\"created_at\"::\"date\"))"
        )

        subject
      end

      it "calls bigserial on table definition" do
        expect(table_definition).to receive(:bigserial).with(:id, null: false)
        subject
      end

      it "calls timestamps on table definition" do
        expect(table_definition).to receive(:timestamps).with(no_args)
        subject
      end
    end
  end

  describe "#create_range_partition_of" do
    let(:partition_clause) do
      <<-SQL
        PARTITION OF "parent"
        FOR VALUES FROM ('1') TO ('10')
      SQL
    end

    let(:create_primary_key) do
      <<-SQL
        ALTER TABLE "child"
        ADD PRIMARY KEY ("id")
      SQL
    end

    before { allow(adapter).to receive(:create_table) }

    context "with name and partition key" do
      subject do
        decorator.create_range_partition_of(
          :parent,
          name: :child,
          partition_key: :key,
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :child,
          id: false,
          options: heredoc_matching(partition_clause)
        )

        subject
      end

      it "calls execute" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key))
        subject
      end

      it "calls add index" do
        expect(adapter).to receive(:add_index).with(:child, "((\"key\"))")
        subject
      end
    end

    context "with composite primary key" do
      subject do
        decorator.create_range_partition_of(
          :parent,
          primary_key: [:id, :id2],
          start_range: 1,
          end_range: 10
        )
      end

      it "raise argument error" do
        expect { subject }.to raise_error(ArgumentError, "composite primary key not supported")
      end
    end

    context "with name and partition key and index false" do
      subject do
        decorator.create_range_partition_of(
          :parent,
          name: :child,
          partition_key: :key,
          index: false,
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :child,
          id: false,
          options: heredoc_matching(partition_clause)
        )

        subject
      end

      it "calls execute" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key))
        subject
      end

      it "does not call add index" do
        expect(adapter).to_not receive(:add_index)
        subject
      end
    end

    context "with name and primary key as partition key" do
      subject do
        decorator.create_range_partition_of(
          :parent,
          name: :child,
          partition_key: :id,
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :child,
          id: false,
          options: heredoc_matching(partition_clause)
        )

        subject
      end

      it "calls execute" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key))
        subject
      end

      it "does not call add index" do
        expect(adapter).to_not receive(:add_index)
        subject
      end
    end

    context "without name and primary key" do
      subject do
        decorator.create_range_partition_of(
          :parent,
          primary_key: false,
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to match(/^parent_\w{7}$/) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          /^parent_\w{7}$/,
          id: false,
          options: heredoc_matching(partition_clause)
        )

        subject
      end

      it "does not call execute" do
        expect(adapter).to_not receive(:execute)
        subject
      end

      it "does not call add index" do
        expect(adapter).to_not receive(:add_index)
        subject
      end
    end
  end

  describe "#create_list_partition_of" do
    let(:partition_clause) do
      <<-SQL
        PARTITION OF "parent"
        FOR VALUES IN ('1','2','3')
      SQL
    end

    let(:create_primary_key) do
      <<-SQL
        ALTER TABLE "child"
        ADD PRIMARY KEY ("id")
      SQL
    end

    before { allow(adapter).to receive(:create_table) }

    context "with name and partition key" do
      subject do
        decorator.create_list_partition_of(
          :parent,
          name: :child,
          partition_key: :key,
          values: [1, 2, 3]
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :child,
          id: false,
          options: heredoc_matching(partition_clause)
        )

        subject
      end

      it "calls execute" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key))
        subject
      end

      it "calls add index" do
        expect(adapter).to receive(:add_index).with(:child, "((\"key\"))")
        subject
      end
    end

    context "with composite primary key" do
      subject do
        decorator.create_list_partition_of(
          :parent,
          primary_key: [:id, :id2],
          values: [1, 2, 3]
        )
      end

      it "raise argument error" do
        expect { subject }.to raise_error(ArgumentError, "composite primary key not supported")
      end
    end
    context "with name and partition key and index false" do
      subject do
        decorator.create_list_partition_of(
          :parent,
          name: :child,
          partition_key: :key,
          index: false,
          values: [1, 2, 3]
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :child,
          id: false,
          options: heredoc_matching(partition_clause)
        )

        subject
      end

      it "calls execute" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key))
        subject
      end

      it "does not call add index" do
        expect(adapter).to_not receive(:add_index)
        subject
      end
    end

    context "with name and primary key as partition key" do
      subject do
        decorator.create_list_partition_of(
          :parent,
          name: :child,
          partition_key: :id,
          values: [1, 2, 3]
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :child,
          id: false,
          options: heredoc_matching(partition_clause)
        )

        subject
      end

      it "calls execute" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key))
        subject
      end

      it "does not call add index" do
        expect(adapter).to_not receive(:add_index)
        subject
      end
    end

    context "without name and primary key" do
      subject do
        decorator.create_list_partition_of(
          :parent,
          primary_key: false,
          values: [1, 2, 3]
        )
      end

      it { is_expected.to match(/^parent_\w{7}$/) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          /^parent_\w{7}$/,
          id: false,
          options: heredoc_matching(partition_clause)
        )

        subject
      end

      it "does not call execute" do
        expect(adapter).to_not receive(:execute)
        subject
      end

      it "does not call add index" do
        expect(adapter).to_not receive(:add_index)
        subject
      end
    end
  end

  describe "#attach_range_partition" do
    let(:expected_sql) do
      <<-SQL
        ALTER TABLE "parent"
        ATTACH PARTITION "child"
        FOR VALUES FROM ('a') TO ('z')
      SQL
    end

    subject { decorator.attach_range_partition("parent", "child", start_range: "a", end_range: "z") }

    it "calls execute with correct SQL" do
      expect(adapter).to receive(:execute).with(heredoc_matching(expected_sql))
      subject
    end
  end

  describe "#attach_list_partition" do
    let(:expected_sql) do
      <<-SQL
        ALTER TABLE "parent"
        ATTACH PARTITION "child"
        FOR VALUES IN ('a','b','c')
      SQL
    end

    subject { decorator.attach_list_partition("parent", "child", values: %w(a b c)) }

    it "calls execute with correct SQL" do
      expect(adapter).to receive(:execute).with(heredoc_matching(expected_sql))
      subject
    end
  end

  describe "#detach_partition" do
    let(:expected_sql) do
      <<-SQL
        ALTER TABLE "parent"
        DETACH PARTITION "child"
      SQL
    end

    subject { decorator.detach_partition("parent", "child") }

    it "calls execute with correct SQL" do
      expect(adapter).to receive(:execute).with(heredoc_matching(expected_sql))
      subject
    end
  end
end
