# frozen_string_literal: true

require "spec_helper"

RSpec.describe UuidStringList do
  let(:connection) { described_class.connection }
  let(:table_name) { described_class.table_name }

  describe ".create" do
    let(:some_string) { "a" }

    subject { described_class.create!(some_string: some_string) }

    context "when partition key in list" do
      its(:id) { is_expected.to be_a_uuid }
      its(:some_string) { is_expected.to eq(some_string) }
    end

    context "when partition key outside list" do
      let(:some_string) { "e" }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::CheckViolation/)
      end
    end
  end

  describe ".partitions" do
    subject { described_class.partitions }

    it { is_expected.to contain_exactly("#{table_name}_a", "#{table_name}_b") }
  end

  describe ".create_partition" do
    let(:values) { ["e", "f"] }
    let(:child_table_name) { "#{table_name}_c" }

    subject(:create_partition) { described_class.create_partition(values: values, name: child_table_name) }
    subject(:partitions) { described_class.partitions }
    subject(:child_table_exists) { PgParty::SchemaHelper.table_exists?(child_table_name) }

    context "when values do not overlap" do
      before { described_class.partitions }
      after { connection.drop_table(child_table_name) }

      it "returns table name and adds it to partition list" do
        expect(create_partition).to eq(child_table_name)

        expect(partitions).to contain_exactly(
          "#{table_name}_a",
          "#{table_name}_b",
          "#{table_name}_c"
        )
      end
    end

    context "when values overlap" do
      let(:values) { ["b", "c"] }

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
      let!(:record_one) { described_class.create!(some_string: "a") }
      let!(:record_two) { described_class.create!(some_string: "b") }
      let!(:record_three) { described_class.create!(some_string: "d") }

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
    let(:values) { ["a", "b"] }

    let!(:record_one) { described_class.create!(some_string: "a") }
    let!(:record_two) { described_class.create!(some_string: "b") }
    let!(:record_three) { described_class.create!(some_string: "d") }

    subject { described_class.partition_key_in(values) }

    context "when spanning a single partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when spanning multiple partitions" do
      let(:values) { ["a", "b", "c", "d"] }

      it { is_expected.to contain_exactly(record_one, record_two, record_three) }
    end

    context "when chaining methods" do
      subject { described_class.partition_key_in(values).where(some_string: "a") }

      it { is_expected.to contain_exactly(record_one) }
    end
  end

  describe ".partition_key_eq" do
    let(:partition_key) { "a" }

    let!(:record_one) { described_class.create!(some_string: "a") }
    let!(:record_two) { described_class.create!(some_string: "c") }

    subject { described_class.partition_key_eq(partition_key) }

    context "when partition key in first partition" do
      it { is_expected.to contain_exactly(record_one) }
    end

    context "when partition key in second partition" do
      let(:partition_key) { "c" }

      it { is_expected.to contain_exactly(record_two) }
    end
  end
end
