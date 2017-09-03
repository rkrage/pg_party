require "spec_helper"

RSpec.describe UuidStringList do
  let(:connection) { described_class.connection }

  describe ".create" do
    let(:some_string) { "a" }

    subject { described_class.create(some_string: some_string) }

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

  describe ".create_partition" do
    let(:values) { ["e", "f"] }
    let(:child_table_name) { subject }

    subject { described_class.create_partition(values: values) }

    context "when values do not overlap" do
      after { connection.drop_table(child_table_name) }

      it { is_expected.to include("uuid_string_lists_") }
    end

    context "when values overlap" do
      let(:values) { ["b", "c"] }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::InvalidObjectDefinition/)
      end
    end
  end

  describe ".partition_key_in" do
    let(:values) { ["a", "b"] }

    let!(:record_one) { described_class.create(some_string: "a") }
    let!(:record_two) { described_class.create(some_string: "b") }
    let!(:record_three) { described_class.create(some_string: "d") }

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

  describe ".partition_key_matching" do
    let(:partition_key) { "a" }

    let!(:record_one) { described_class.create(some_string: "a") }
    let!(:record_two) { described_class.create(some_string: "c") }

    subject { described_class.partition_key_matching(partition_key) }

    context "when partition key in first partition" do
      it { is_expected.to contain_exactly(record_one) }
    end

    context "when partition key in second partition" do
      let(:partition_key) { "c" }

      it { is_expected.to contain_exactly(record_two) }
    end
  end
end
