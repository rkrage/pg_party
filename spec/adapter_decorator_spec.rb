# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::AdapterDecorator do
  let(:adapter) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }
  let(:table_definition) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition) }
  let(:pg_version) { 100000 }
  let(:uuid_function) do
    if Rails.gem_version >= Gem::Version.new("5.1")
      "gen_random_uuid()"
    else
      "uuid_generate_v4()"
    end
  end

  before do
    allow(adapter).to receive(:postgresql_version).and_return(pg_version)
    allow(adapter).to receive(:execute)
    allow(adapter).to receive(:change_column_null)
    allow(adapter).to receive(:quote_table_name) { |name| "\"#{name}\"" }
    allow(adapter).to receive(:quote_column_name) { |name| "\"#{name}\"" }
    allow(adapter).to receive(:quote) { |value| "'#{value}'" }

    if uuid_function == "gen_random_uuid()"
      allow(adapter).to receive(:supports_pgcrypto_uuid?).and_return(true)
    end

    allow(table_definition).to receive(:column)
    allow(table_definition).to receive(:integer)
    allow(table_definition).to receive(:timestamps)

    allow(PgParty::Cache).to receive(:clear!)
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
          options: "PARTITION BY RANGE (\"id\")"
        )

        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(:id, :bigserial, null: false)
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
          options: "PARTITION BY RANGE (\"id\")"
        )

        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(:id, :serial, null: false)
        subject
      end
    end

    context "with uuid primary key" do
      subject { decorator.create_range_partition(:table_name, partition_key: :id, id: :uuid) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY RANGE (\"id\")"
        )

        subject
      end

      it "calls change_column_null" do
        expect(adapter).to receive(:change_column_null).with(:table_name, :id, false)
        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(
          :id,
          :uuid,
          null: false,
          default: uuid_function
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
          options: "PARTITION BY RANGE (\"some_column\")"
        )

        subject
      end

      it "does not call column on table definition" do
        expect(table_definition).to_not receive(:column)
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
          options: "PARTITION BY RANGE (\"uid\")"
        )

        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(:uid, :bigserial, null: false)
        subject
      end
    end

    context "with complex partition key" do
      subject do
        decorator.create_range_partition(:table_name, partition_key: ->{ "(created_at::date)" }) do |t|
          t.timestamps null: false
        end
      end

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY RANGE ((created_at::date))"
        )

        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(:id, :bigserial, null: false)
        subject
      end

      it "calls timestamps on table definition" do
        expect(table_definition).to receive(:timestamps).with(null: false)
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
          options: "PARTITION BY LIST (\"id\")"
        )

        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(:id, :bigserial, null: false)
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
          options: "PARTITION BY LIST (\"id\")"
        )

        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(:id, :serial, null: false)
        subject
      end
    end

    context "with uuid primary key" do
      subject { decorator.create_list_partition(:table_name, partition_key: :id, id: :uuid) }

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY LIST (\"id\")"
        )

        subject
      end

      it "calls change_column_null" do
        expect(adapter).to receive(:change_column_null).with(:table_name, :id, false)
        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(
          :id,
          :uuid,
          null: false,
          default: uuid_function
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
          options: "PARTITION BY LIST (\"some_column\")"
        )

        subject
      end

      it "does not call column on table definition" do
        expect(table_definition).to_not receive(:column)
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
          options: "PARTITION BY LIST (\"uid\")"
        )

        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(:uid, :bigserial, null: false)
        subject
      end
    end

    context "with complex partition key" do
      subject do
        decorator.create_list_partition(:table_name, partition_key: ->{ "(created_at::date)"}) do |t|
          t.timestamps null: false
        end
      end

      it "calls create table" do
        expect(adapter).to receive(:create_table).with(
          :table_name,
          id: false,
          options: "PARTITION BY LIST ((created_at::date))"
        )

        subject
      end

      it "calls column on table definition" do
        expect(table_definition).to receive(:column).with(:id, :bigserial, null: false)
        subject
      end

      it "calls timestamps on table definition" do
        expect(table_definition).to receive(:timestamps).with(null: false)
        subject
      end
    end
  end

  describe "#create_range_partition_of" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE "child"
        PARTITION OF "parent"
        FOR VALUES FROM ('1') TO ('10')
      SQL
    end

    let(:create_primary_key_sql) do
      <<-SQL
        ALTER TABLE "child"
        ADD PRIMARY KEY ("id")
      SQL
    end

    let(:create_index_sql) do
      <<-SQL
        CREATE INDEX "index_child_on_partition_key"
        ON "child"
        USING btree ("key")
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

      it "calls execute to create table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "calls execute to add primary key" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key_sql))
        subject
      end

      it "calls execute to add index" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_index_sql))
        subject
      end

      it "calls clear! on cache" do
        expect(PgParty::Cache).to receive(:clear!)
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

      it "calls execute to create table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "calls execute to add primary key" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key_sql))
        subject
      end

      it "does not call execute to add index" do
        expect(adapter).to_not receive(:execute).with(/CREATE INDEX/)
        subject
      end

      it "calls clear! on cache" do
        expect(PgParty::Cache).to receive(:clear!)
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

      it "calls execute to create table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "calls execute to add primary key" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key_sql))
        subject
      end

      it "does not call execute to add index" do
        expect(adapter).to_not receive(:execute).with(/CREATE INDEX/)
        subject
      end

      it "calls clear! on cache" do
        expect(PgParty::Cache).to receive(:clear!)
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

      it "calls execute to create table" do
        expect(adapter).to receive(:execute).with(/CREATE TABLE/)
        subject
      end

      it "does not call execute to add primary key" do
        expect(adapter).to_not receive(:execute).with(/ALTER TABLE/)
        subject
      end

      it "does not call execute to add index" do
        expect(adapter).to_not receive(:execute).with(/CREATE INDEX/)
        subject
      end

      it "calls clear! on cache" do
        expect(PgParty::Cache).to receive(:clear!)
        subject
      end
    end
  end

  describe "#create_list_partition_of" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE "child"
        PARTITION OF "parent"
        FOR VALUES IN ('1','2','3')
      SQL
    end

    let(:create_primary_key_sql) do
      <<-SQL
        ALTER TABLE "child"
        ADD PRIMARY KEY ("id")
      SQL
    end

    let(:create_index_sql) do
      <<-SQL
        CREATE INDEX "index_child_on_partition_key"
        ON "child"
        USING btree ("key")
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

      it "calls execute to create table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "calls execute to add primary key" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key_sql))
        subject
      end

      it "calls execute to add index" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_index_sql))
        subject
      end

      it "calls clear! on cache" do
        expect(PgParty::Cache).to receive(:clear!)
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

      it "calls execute to create table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "calls execute to add primary key" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key_sql))
        subject
      end

      it "does not call execute to add index" do
        expect(adapter).to_not receive(:execute).with(/CREATE INDEX/)
        subject
      end

      it "calls clear! on cache" do
        expect(PgParty::Cache).to receive(:clear!)
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

      it "calls execute to create table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "calls execute to add primary key" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key_sql))
        subject
      end

      it "does not call execute to add index" do
        expect(adapter).to_not receive(:execute).with(/CREATE INDEX/)
        subject
      end

      it "calls clear! on cache" do
        expect(PgParty::Cache).to receive(:clear!)
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

      it "calls execute to create table" do
        expect(adapter).to receive(:execute).with(/CREATE TABLE/)
        subject
      end

      it "does not call execute to add primary key" do
        expect(adapter).to_not receive(:execute).with(/ALTER TABLE/)
        subject
      end

      it "does not call execute to add index" do
        expect(adapter).to_not receive(:execute).with(/CREATE INDEX/)
        subject
      end

      it "calls clear! on cache" do
        expect(PgParty::Cache).to receive(:clear!)
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

    it "calls clear! on cache" do
      expect(PgParty::Cache).to receive(:clear!)
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

    it "calls clear! on cache" do
      expect(PgParty::Cache).to receive(:clear!)
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

    it "calls clear! on cache" do
      expect(PgParty::Cache).to receive(:clear!)
      subject
    end
  end
end
