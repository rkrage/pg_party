# frozen_string_literal: true

require "spec_helper"

RSpec.describe BigintBooleanList do
  let(:connection) { described_class.connection }
  let(:schema_cache) { connection.schema_cache }
  let(:table_name) { described_class.table_name }

  describe ".primary_key" do
    subject { described_class.primary_key }

    it { is_expected.to eq("id") }
  end

  describe ".create" do
    let(:some_bool) { true }

    subject { described_class.create!(some_bool: some_bool) }

    context "when partition key in list" do
      its(:id) { is_expected.to be_an(Integer) }
      its(:some_bool) { is_expected.to eq(some_bool) }
    end
  end

  describe ".partitions" do
    subject { described_class.partitions }

    it { is_expected.to contain_exactly("#{table_name}_a", "#{table_name}_b") }
  end

  describe ".create_partition" do
    let(:values) { true }
    let(:child_table_name) { "#{table_name}_c" }

    subject(:create_partition) { described_class.create_partition(values: values, name: child_table_name) }
    subject(:child_table_exists) { schema_cache.data_source_exists?(child_table_name) }

    context "when values overlap" do
      it "raises error and cleans up intermediate table" do
        expect { create_partition }.to raise_error(ActiveRecord::StatementInvalid, /PG::InvalidObjectDefinition/)
        expect(child_table_exists).to eq(false)
      end
    end
  end

  describe ".in_partition" do
    let(:child_table_name) { "#{table_name}_a" }

    subject { described_class.in_partition(child_table_name) }

    its(:table_name) { is_expected.to eq(child_table_name) }
    its(:name)       { is_expected.to eq(described_class.name) }
    its(:new)        { is_expected.to be_an_instance_of(described_class) }
    its(:allocate)   { is_expected.to be_an_instance_of(described_class) }

    describe "query methods" do
      let!(:record_one) { described_class.create!(some_bool: true) }
      let!(:record_two) { described_class.create!(some_bool: true) }
      let!(:record_three) { described_class.create!(some_bool: false) }

      describe ".all" do
        subject { described_class.in_partition(child_table_name).all }

        it { is_expected.to contain_exactly(record_one, record_two) }
      end

      describe ".where" do
        subject { described_class.in_partition(child_table_name).where(id: record_one.id) }

        it { is_expected.to contain_exactly(record_one) }
      end
    end
  end

  describe ".partition_key_in" do
    let(:values) { true }

    let!(:record_one) { described_class.create!(some_bool: true) }
    let!(:record_two) { described_class.create!(some_bool: true) }
    let!(:record_three) { described_class.create!(some_bool: false) }

    subject { described_class.partition_key_in(values) }

    context "when spanning a single partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when spanning multiple partitions" do
      let(:values) { [true, false] }

      it { is_expected.to contain_exactly(record_one, record_two, record_three) }
    end

    context "when chaining methods" do
      let(:values) { false }

      subject { described_class.partition_key_in(values).where(some_bool: false) }

      it { is_expected.to contain_exactly(record_three) }
    end
  end

  describe ".partition_key_eq" do
    let(:partition_key) { true }

    let!(:record_one) { described_class.create!(some_bool: true) }
    let!(:record_two) { described_class.create!(some_bool: false) }

    subject { described_class.partition_key_eq(partition_key) }

    context "when partition key in first partition" do
      it { is_expected.to contain_exactly(record_one) }
    end

    context "when partition key in second partition" do
      let(:partition_key) { false }

      it { is_expected.to contain_exactly(record_two) }
    end

    context "when table is aliased" do
      subject do
        described_class
          .select("*")
          .from(described_class.arel_table.alias)
          .partition_key_eq(partition_key)
      end

      it { is_expected.to contain_exactly(record_one) }
    end

    context "when table alias not resolvable" do
      subject do
        described_class
          .select("*")
          .from("garbage")
          .partition_key_eq(partition_key)
      end

      it { expect { subject }.to raise_error("could not find arel table in current scope") }
    end
  end
end
