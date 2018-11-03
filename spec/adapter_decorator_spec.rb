# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::AdapterDecorator do
  let(:adapter) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }
  let(:table_definition) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition) }
  let(:pg_version) { 100000 }
  let(:primary_key) { :id }
  let(:template_table_exists) { true }
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
    allow(adapter).to receive(:primary_key).and_return(primary_key)
    allow(ActiveRecord::Base).to receive(:get_primary_key).and_return("id")
    allow(PgParty::SchemaHelper).to receive(:table_exists?).and_return(template_table_exists)

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
    let(:attach_partition_sql) do
      <<-SQL
        ALTER TABLE "parent"
        ATTACH PARTITION "child"
        FOR VALUES FROM ('1') TO ('10')
      SQL
    end

    before { allow(decorator).to receive(:create_table_like) }

    context "with name, primary key, and template table present" do
      subject do
        decorator.create_range_partition_of(
          :parent,
          name: :child,
          primary_key: :some_pk, # this is ignored - it's assumed that the template table already has a pk
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create_table_like with template table" do
        expect(decorator).to receive(:create_table_like).with("parent_template", :child)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(attach_partition_sql))
        subject
      end
    end

    context "with name and template table present" do
      subject do
        decorator.create_range_partition_of(
          :parent,
          name: :child,
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create_table_like with template table" do
        expect(decorator).to receive(:create_table_like).with("parent_template", :child)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(attach_partition_sql))
        subject
      end
    end

    context "with template table present" do
      subject do
        decorator.create_range_partition_of(
          :parent,
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to match(/^parent_/) }

      it "calls create_table_like with template table" do
        expect(decorator).to receive(:create_table_like).with("parent_template", /^parent_/)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(/ATTACH PARTITION/)
        subject
      end
    end

    context "with name, primary key, and template table not present" do
      let(:template_table_exists) { false }

      subject do
        decorator.create_range_partition_of(
          :parent,
          name: :child,
          primary_key: :some_pk,
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create_table_like with parent table" do
        expect(decorator).to receive(:create_table_like).with(:parent, :child, primary_key: :some_pk)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(attach_partition_sql))
        subject
      end
    end

    context "with name and template table not present" do
      let(:template_table_exists) { false }

      subject do
        decorator.create_range_partition_of(
          :parent,
          name: :child,
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create_table_like with parent table" do
        expect(decorator).to receive(:create_table_like).with(:parent, :child, primary_key: :id)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(attach_partition_sql))
        subject
      end
    end

    context "with template table not present" do
      let(:template_table_exists) { false }

      subject do
        decorator.create_range_partition_of(
          :parent,
          start_range: 1,
          end_range: 10
        )
      end

      it { is_expected.to match(/^parent_/) }

      it "calls create_table_like with parent table" do
        expect(decorator).to receive(:create_table_like).with(:parent, /^parent_/, primary_key: :id)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(/ATTACH PARTITION/)
        subject
      end
    end
  end

  describe "#create_list_partition_of" do
    let(:attach_partition_sql) do
      <<-SQL
        ALTER TABLE "parent"
        ATTACH PARTITION "child"
        FOR VALUES IN ('1','2','3')
      SQL
    end

    before { allow(decorator).to receive(:create_table_like) }

    context "with name, primary key, and template table present" do
      subject do
        decorator.create_list_partition_of(
          :parent,
          name: :child,
          primary_key: :some_pk, # this is ignored - it's assumed that the template table already has a pk
          values: [1, 2, 3]
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create_table_like with template table" do
        expect(decorator).to receive(:create_table_like).with("parent_template", :child)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(attach_partition_sql))
        subject
      end
    end

    context "with name and template table present" do
      subject do
        decorator.create_list_partition_of(
          :parent,
          name: :child,
          values: [1, 2, 3]
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create_table_like with template table" do
        expect(decorator).to receive(:create_table_like).with("parent_template", :child)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(attach_partition_sql))
        subject
      end
    end

    context "with template table present" do
      subject do
        decorator.create_list_partition_of(
          :parent,
          values: [1, 2, 3]
        )
      end

      it { is_expected.to match(/^parent_/) }

      it "calls create_table_like with template table" do
        expect(decorator).to receive(:create_table_like).with("parent_template", /^parent_/)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(/ATTACH PARTITION/)
        subject
      end
    end

    context "with name, primary key, and template table not present" do
      let(:template_table_exists) { false }

      subject do
        decorator.create_list_partition_of(
          :parent,
          name: :child,
          primary_key: :some_pk,
          values: [1, 2, 3]
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create_table_like with parent table" do
        expect(decorator).to receive(:create_table_like).with(:parent, :child, primary_key: :some_pk)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(attach_partition_sql))
        subject
      end
    end

    context "with name and template table not present" do
      let(:template_table_exists) { false }

      subject do
        decorator.create_list_partition_of(
          :parent,
          name: :child,
          values: [1, 2, 3]
        )
      end

      it { is_expected.to eq(:child) }

      it "calls create_table_like with parent table" do
        expect(decorator).to receive(:create_table_like).with(:parent, :child, primary_key: :id)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(heredoc_matching(attach_partition_sql))
        subject
      end
    end

    context "with template table not present" do
      let(:template_table_exists) { false }

      subject do
        decorator.create_list_partition_of(
          :parent,
          values: [1, 2, 3]
        )
      end

      it { is_expected.to match(/^parent_/) }

      it "calls create_table_like with parent table" do
        expect(decorator).to receive(:create_table_like).with(:parent, /^parent_/, primary_key: :id)
        subject
      end

      it "calls execute to attach child table" do
        expect(adapter).to receive(:execute).with(/ATTACH PARTITION/)
        subject
      end
    end
  end

  describe "#create_table_like" do
    let(:create_table_sql) do
      <<-SQL
        CREATE TABLE "table_b" (
          LIKE "table_a" INCLUDING ALL
        )
      SQL
    end

    let(:create_primary_key_sql) do
      <<-SQL
        ALTER TABLE "table_b"
        ADD PRIMARY KEY ("id")
      SQL
    end

    subject { decorator.create_table_like(:table_a, :table_b) }

    context "when parent table has primary key" do
      it "creates table with the correct SQL" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "does not create primary key" do
        expect(adapter).to_not receive(:execute).with(/ALTER TABLE/)
        subject
      end
    end

    context "when parent table does not have primary key" do
      let(:primary_key) { nil }

      it "creates table with the correct SQL" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "creates primary key with the correct SQL" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key_sql))
        subject
      end
    end

    context "when parent table does not have primary key and false primary key provided" do
      let(:primary_key) { nil }

      subject { decorator.create_table_like(:table_a, :table_b, primary_key: false) }

      it "creates table with the correct SQL" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "does not create primary key" do
        expect(adapter).to_not receive(:execute).with(/ALTER TABLE/)
        subject
      end
    end

    context "when parent table does not have primary key and custom key provided" do
      let(:primary_key) { nil }
      let(:create_primary_key_sql) do
        <<-SQL
          ALTER TABLE "table_b"
          ADD PRIMARY KEY ("custom_id")
        SQL
      end

      subject { decorator.create_table_like(:table_a, :table_b, primary_key: :custom_id) }

      it "creates table with the correct SQL" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_table_sql))
        subject
      end

      it "creates primary key with the correct SQL" do
        expect(adapter).to receive(:execute).with(heredoc_matching(create_primary_key_sql))
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
