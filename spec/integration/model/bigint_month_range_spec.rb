# frozen_string_literal: true

require "spec_helper"

RSpec.describe BigintMonthRange do
  let(:current_date) { Date.current }
  let(:current_time) { Time.current }
  let(:connection) { described_class.connection }
  let(:schema_cache) { connection.schema_cache }
  let(:table_name) { described_class.table_name }

  describe ".primary_key" do
    subject { described_class.primary_key }

    it { is_expected.to eq("id") }
  end

  describe ".create" do
    let(:created_at) { current_time }

    subject { described_class.create!(created_at: created_at) }

    context "when partition key in range" do
      its(:id) { is_expected.to be_an(Integer) }
      its(:created_at) { is_expected.to eq(created_at) }
    end

    context "when partition key outside range" do
      let(:created_at) { current_time - 1.month }

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
      before { allow(PgParty::Cache).to receive(:fetch_partitions).and_raise("boom") }

      it { is_expected.to eq([]) }
    end
  end

  describe ".create_partition" do
    let(:start_date) { current_date + 2.months }
    let(:end_date) { current_date + 3.months }
    let(:start_range) { [start_date.year, start_date.month] }
    let(:end_range) { [end_date.year, end_date.month] }
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
      let(:start_date) { current_date - 1.month }

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
      let!(:record_one) { described_class.create!(created_at: current_time) }
      let!(:record_two) { described_class.create!(created_at: current_time.end_of_month) }
      let!(:record_three) { described_class.create!(created_at: (current_time + 1.month).end_of_month) }

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
    let(:start_date) { current_date }
    let(:end_date) { current_date + 1.month }
    let(:start_range) { [start_date.year, start_date.month] }
    let(:end_range) { [end_date.year, end_date.month] }

    let!(:record_one) { described_class.create!(created_at: current_time) }
    let!(:record_two) { described_class.create!(created_at: current_time.end_of_month) }
    let!(:record_three) { described_class.create!(created_at: (current_time + 1.month).end_of_month) }

    subject { described_class.partition_key_in(start_range, end_range) }

    context "when spanning a single partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when spanning multiple partitions" do
      let(:end_date) { current_date + 2.months }

      it { is_expected.to contain_exactly(record_one, record_two, record_three) }
    end

    context "when chaining methods" do
      subject { described_class.partition_key_in(start_range, end_range).where(id: record_one.id) }

      it { is_expected.to contain_exactly(record_one) }
    end
  end

  describe ".partition_key_eq" do
    let(:partition_date) { current_date }
    let(:partition_key) { [partition_date.year, partition_date.month] }

    let!(:record_one) { described_class.create!(created_at: current_time) }
    let!(:record_two) { described_class.create!(created_at: current_time.end_of_month) }
    let!(:record_three) { described_class.create!(created_at: (current_time + 1.month).end_of_month) }

    subject { described_class.partition_key_eq(partition_key) }

    context "when partition key in first partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when partition key in second partition" do
      let(:partition_date) { current_date + 1.month }

      it { is_expected.to contain_exactly(record_three) }
    end

    context "when table is aliased" do
      subject do
        described_class
          .select("*")
          .from(described_class.arel_table.alias)
          .partition_key_eq(partition_key)
      end

      it { is_expected.to contain_exactly(record_one, record_two) }
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
