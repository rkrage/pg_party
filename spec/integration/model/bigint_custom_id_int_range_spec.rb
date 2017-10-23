require "spec_helper"

RSpec.describe BigintCustomIdIntRange do
  let(:connection) { described_class.connection }
  let(:table_name) { described_class.table_name }

  describe ".create" do
    let(:some_int) { 5 }

    subject { described_class.create(some_int: some_int) }

    context "when partition key in range" do
      its(:id) { is_expected.to be_a(Integer) }
      its(:some_int) { is_expected.to eq(some_int) }
    end

    context "when partition key outside range" do
      let(:some_int) { 20 }

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
    let(:start_range) { 20 }
    let(:end_range) { 30 }
    let(:child_table_name) { "#{table_name}_c" }

    subject do
      described_class.create_partition(
        start_range: start_range,
        end_range: end_range,
        name: child_table_name
      )
    end

    context "when ranges do not overlap" do
      before { described_class.partitions }
      after { connection.drop_table(child_table_name) }

      it { is_expected.to eq(child_table_name) }

      it "adds to partition list" do
        subject

        expect(described_class.partitions).to contain_exactly(
          "#{table_name}_a",
          "#{table_name}_b",
          "#{table_name}_c"
        )
      end
    end

    context "when ranges overlap" do
      let(:start_range) { 19 }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::InvalidObjectDefinition/)
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
      let!(:record_one) { described_class.create(some_int: 0) }
      let!(:record_two) { described_class.create(some_int: 9) }
      let!(:record_three) { described_class.create(some_int: 19) }

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
    let(:start_range) { 0 }
    let(:end_range) { 10 }

    let!(:record_one) { described_class.create(some_int: 0) }
    let!(:record_two) { described_class.create(some_int: 9) }
    let!(:record_three) { described_class.create(some_int: 19) }

    subject { described_class.partition_key_in(start_range, end_range) }

    context "when spanning a single partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when spanning multiple partitions" do
      let(:end_range) { 20 }

      it { is_expected.to contain_exactly(record_one, record_two, record_three) }
    end

    context "when chaining methods" do
      subject { described_class.partition_key_in(start_range, end_range).where(some_int: 0) }

      it { is_expected.to contain_exactly(record_one) }
    end
  end

  describe ".partition_key_eq" do
    let(:partition_key) { 0 }

    let!(:record_one) { described_class.create(some_int: 0) }
    let!(:record_two) { described_class.create(some_int: 10) }

    subject { described_class.partition_key_eq(partition_key) }

    context "when partition key in first partition" do
      it { is_expected.to contain_exactly(record_one) }
    end

    context "when partition key in second partition" do
      let(:partition_key) { 10 }

      it { is_expected.to contain_exactly(record_two) }
    end
  end
end
