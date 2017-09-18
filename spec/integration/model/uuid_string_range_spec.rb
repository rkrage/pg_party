require "spec_helper"

RSpec.describe UuidStringRange do
  let(:connection) { described_class.connection }

  describe ".create" do
    let(:some_string) { "c" }

    subject { described_class.create(some_string: some_string) }

    context "when partition key in range" do
      its(:id) { is_expected.to be_a_uuid }
      its(:some_string) { is_expected.to eq(some_string) }
    end

    context "when partition key outside range" do
      let(:some_string) { "z" }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::CheckViolation/)
      end
    end
  end

  describe ".create_partition" do
    let(:start_range) { "0" }
    let(:end_range) { "9" }
    let(:child_table_name) { subject }

    subject { described_class.create_partition(start_range: start_range, end_range: end_range) }

    context "when ranges do not overlap" do
      after { connection.drop_table(child_table_name) }

      it { is_expected.to include("uuid_string_ranges_") }
    end

    context "when ranges overlap" do
      let(:end_range) { "b" }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::InvalidObjectDefinition/)
      end
    end
  end

  describe ".partition_key_in" do
    let(:start_range) { "a" }
    let(:end_range) { "l" }

    let!(:record_one) { described_class.create(some_string: "d") }
    let!(:record_two) { described_class.create(some_string: "f") }
    let!(:record_three) { described_class.create(some_string: "x") }

    subject { described_class.partition_key_in(start_range, end_range) }

    context "when spanning a single partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when spanning multiple partitions" do
      let(:end_range) { "z" }

      it { is_expected.to contain_exactly(record_one, record_two, record_three) }
    end

    context "when chaining methods" do
      subject { described_class.partition_key_in(start_range, end_range).where(some_string: "d") }

      it { is_expected.to contain_exactly(record_one) }
    end
  end

  describe ".partition_key_eq" do
    let(:partition_key) { "d" }

    let!(:record_one) { described_class.create(some_string: "d") }
    let!(:record_two) { described_class.create(some_string: "x") }

    subject { described_class.partition_key_eq(partition_key) }

    context "when partition key in first partition" do
      it { is_expected.to contain_exactly(record_one) }
    end

    context "when partition key in second partition" do
      let(:partition_key) { "x" }

      it { is_expected.to contain_exactly(record_two) }
    end
  end
end
