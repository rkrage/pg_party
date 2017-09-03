require "spec_helper"

RSpec.describe BigintCustomIdIntList do
  let(:connection) { described_class.connection }

  describe ".create" do
    let(:some_int) { 1 }

    subject { described_class.create(some_int: some_int) }

    context "when partition key in list" do
      its(:id) { is_expected.to be_a(Integer) }
      its(:some_int) { is_expected.to eq(some_int) }
    end

    context "when partition key outside list" do
      let(:some_int) { 5 }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::CheckViolation/)
      end
    end
  end

  describe ".create_partition" do
    let(:values) { [5, 6] }
    let(:child_table_name) { subject }

    subject { described_class.create_partition(values: values) }

    context "when values do not overlap" do
      after { connection.drop_table(child_table_name) }

      it { is_expected.to include("bigint_custom_id_int_lists_") }
    end

    context "when values overlap" do
      let(:values) { [2, 3] }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::InvalidObjectDefinition/)
      end
    end
  end

  describe ".partition_key_in" do
    let(:values) { [1, 2] }

    let!(:record_one) { described_class.create(some_int: 1) }
    let!(:record_two) { described_class.create(some_int: 2) }
    let!(:record_three) { described_class.create(some_int: 4) }

    subject { described_class.partition_key_in(values) }

    context "when spanning a single partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when spanning multiple partitions" do
      let(:values) { [1, 2, 3, 4] }

      it { is_expected.to contain_exactly(record_one, record_two, record_three) }
    end

    context "when chaining methods" do
      subject { described_class.partition_key_in(values).where(some_int: 1) }

      it { is_expected.to contain_exactly(record_one) }
    end
  end

  describe ".partition_key_matching" do
    let(:partition_key) { 1 }

    let!(:record_one) { described_class.create(some_int: 1) }
    let!(:record_two) { described_class.create(some_int: 3) }

    subject { described_class.partition_key_matching(partition_key) }

    context "when partition key in first partition" do
      it { is_expected.to contain_exactly(record_one) }
    end

    context "when partition key in second partition" do
      let(:partition_key) { 3 }

      it { is_expected.to contain_exactly(record_two) }
    end
  end
end
