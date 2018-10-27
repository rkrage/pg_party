# frozen_string_literal: true

require "spec_helper"

RSpec.describe BigintDateRange do
  let(:current_date) { Date.current }
  let(:current_time) { Time.current }
  let(:connection) { described_class.connection }
  let(:table_name) { described_class.table_name }

  describe ".create" do
    let(:created_at) { current_time }

    subject { described_class.create(created_at: created_at) }

    context "when partition key in range" do
      its(:id) { is_expected.to be_an(Integer) }
      its(:created_at) { is_expected.to eq(created_at) }
    end

    context "when partition key outside range" do
      let(:created_at) { current_time - 10.days }

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
    let(:start_range) { current_date + 2.days }
    let(:end_range) { current_date + 3.days }
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
      let(:start_range) { current_date }

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
      let!(:record_one) { described_class.create(created_at: current_time) }
      let!(:record_two) { described_class.create(created_at: current_time + 1.minute) }
      let!(:record_three) { described_class.create(created_at: current_time + 1.day) }

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
    let(:start_range) { current_date }
    let(:end_range) { current_date + 1.day }
    let(:error_message) { "#partition_key_in not available for complex partition keys" }

    subject { described_class.partition_key_in(start_range, end_range) }

    it "raises error" do
      expect { subject }.to raise_error(RuntimeError, error_message)
    end
  end

  describe ".partition_key_eq" do
    let(:partition_key) { current_date }
    let(:error_message) { "#partition_key_eq not available for complex partition keys" }

    subject { described_class.partition_key_eq(partition_key) }

    it "raises error" do
      expect { subject }.to raise_error(RuntimeError, error_message)
    end
  end
end
