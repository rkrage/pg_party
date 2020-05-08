# frozen_string_literal: true

require "spec_helper"

RSpec.describe BigintCustomIdIntRange do
  let(:connection) { described_class.connection }
  let(:schema_cache) { connection.schema_cache }
  let(:table_name) { described_class.table_name }

  describe ".primary_key" do
    subject { described_class.primary_key }

    it { is_expected.to eq("some_id") }
  end

  describe ".create" do
    let(:some_int) { 1 }
    let(:some_other_int) { 9 }

    subject do
      described_class.create!(
        some_int: some_int,
        some_other_int: some_other_int,
      )
    end

    context "when partition key in range" do
      its(:id) { is_expected.to be_a(Integer) }
      its(:some_int) { is_expected.to eq(some_int) }
      its(:some_other_int) { is_expected.to eq(some_other_int) }
    end

    context "when partition key outside range" do
      let(:some_int) { 20 }
      let(:some_other_int) { 20 }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::CheckViolation/)
      end
    end
  end

  describe ".partitions" do
    subject { described_class.partitions }

    context "when query successful" do
      it { is_expected.to contain_exactly("#{table_name}_a", "#{table_name}_b") }
    end

    context "when an error occurs" do
      before { allow(PgParty.cache).to receive(:fetch_partitions).and_raise("boom") }

      it { is_expected.to eq([]) }
    end
  end

  describe ".create_partition" do
    let(:start_range) { [20, 20] }
    let(:end_range) { [30, 30] }
    let(:child_table_name) { "#{table_name}_c" }

    subject(:create_partition) do
      described_class.create_partition(
        start_range: start_range,
        end_range: end_range,
        name: child_table_name
      )
    end

    subject(:partitions) { described_class.partitions }
    subject(:child_table_exists) { schema_cache.data_source_exists?(child_table_name) }

    before do
      schema_cache.clear!
      described_class.partitions
    end

    after { connection.drop_table(child_table_name) if child_table_exists }

    context "when ranges do not overlap" do
      it "returns table name and adds it to partition list" do
        expect(create_partition).to eq(child_table_name)

        expect(partitions).to contain_exactly(
          "#{table_name}_a",
          "#{table_name}_b",
          "#{table_name}_c"
        )
      end
    end

    context "when name not provided" do
      let(:child_table_name) { create_partition }

      subject(:create_partition) do
        described_class.create_partition(
          start_range: start_range,
          end_range: end_range,
        )
      end

      it "returns table name and adds it to partition list" do
        expect(create_partition).to match(/^#{table_name}_\w{7}$/)

        expect(partitions).to contain_exactly(
          "#{table_name}_a",
          "#{table_name}_b",
          child_table_name,
        )
      end
    end

    context "when ranges overlap" do
      let(:start_range) { [19, 19] }

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
      let!(:record_one) { described_class.create!(some_int: 0, some_other_int: 0) }
      let!(:record_two) { described_class.create!(some_int: 9, some_other_int: 9) }
      let!(:record_three) { described_class.create!(some_int: 19, some_other_int: 19) }

      describe ".all" do
        subject { described_class.in_partition(child_table_name).all }

        it { is_expected.to contain_exactly(record_one, record_two) }
      end

      describe ".where" do
        subject { described_class.in_partition(child_table_name).where(some_id: record_one.some_id) }

        it { is_expected.to contain_exactly(record_one) }
      end
    end
  end

  describe ".partition_key_in" do
    let(:start_range) { [0, 0] }
    let(:end_range) { [10, 10] }

    let!(:record_one) { described_class.create!(some_int: 0, some_other_int: 0) }
    let!(:record_two) { described_class.create!(some_int: 9, some_other_int: 9) }
    let!(:record_three) { described_class.create!(some_int: 19, some_other_int: 19) }

    subject { described_class.partition_key_in(start_range, end_range) }

    context "when spanning a single partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when spanning multiple partitions" do
      let(:end_range) { [20, 20] }

      it { is_expected.to contain_exactly(record_one, record_two, record_three) }
    end

    context "when chaining methods" do
      subject { described_class.partition_key_in(start_range, end_range).where(some_int: 0) }

      it { is_expected.to contain_exactly(record_one) }
    end

    context "when incorrect number of values provided" do
      let(:start_range) { 0 }

      it "raises error" do
        expect { subject }.to raise_error(/does not match the number of partition key columns/)
      end
    end
  end

  describe ".partition_key_eq" do
    let(:partition_key) { [0, 0] }

    let!(:record_one) { described_class.create!(some_int: 0, some_other_int: 0) }
    let!(:record_two) { described_class.create!(some_int: 10, some_other_int: 10) }

    subject { described_class.partition_key_eq(partition_key) }

    context "when partition key in first partition" do
      it { is_expected.to contain_exactly(record_one) }
    end

    context "when partition key in second partition" do
      let(:partition_key) { [10, 10] }

      it { is_expected.to contain_exactly(record_two) }
    end

    context "when chaining methods" do
      subject do
        described_class
          .in_partition("#{table_name}_b")
          .unscoped
          .partition_key_eq(partition_key)
      end

      it { is_expected.to be_empty }
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
