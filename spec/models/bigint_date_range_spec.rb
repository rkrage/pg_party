require "spec_helper"

RSpec.describe BigintDateRange do
  let(:current_date) { Date.current }
  let(:current_time) { Time.current }
  let(:connection) { described_class.connection }

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

  describe ".create_partition" do
    let(:start_range) { current_date + 2.days }
    let(:end_range) { current_date + 3.days }
    let(:child_table_name) { subject }

    subject { described_class.create_partition(start_range: start_range, end_range: end_range) }

    context "when ranges do not overlap" do
      after { connection.drop_table(child_table_name) }

      it { is_expected.to include("bigint_date_ranges_") }
    end

    context "when ranges overlap" do
      let(:start_range) { current_date }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::InvalidObjectDefinition/)
      end
    end
  end

  describe ".partition_key_in" do
    let(:start_range) { current_date }
    let(:end_range) { current_date + 1.day }

    let!(:record_one) { described_class.create(created_at: current_time) }
    let!(:record_two) { described_class.create(created_at: current_time + 1.minute) }
    let!(:record_three) { described_class.create(created_at: current_time + 1.day) }

    subject { described_class.partition_key_in(start_range, end_range) }

    context "when spanning a single partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when spanning multiple partitions" do
      let(:end_range) { current_date + 2.days }

      it { is_expected.to contain_exactly(record_one, record_two, record_three) }
    end

    context "when chaining methods" do
      subject { described_class.partition_key_in(start_range, end_range).where(id: record_one.id) }

      it { is_expected.to contain_exactly(record_one) }
    end
  end

  describe ".partition_key_matching" do
    let(:partition_key) { current_date }

    let!(:record_one) { described_class.create(created_at: current_time) }
    let!(:record_two) { described_class.create(created_at: current_time + 1.minute) }
    let!(:record_three) { described_class.create(created_at: current_time + 1.day) }

    subject { described_class.partition_key_matching(partition_key) }

    context "when partition key in first partition" do
      it { is_expected.to contain_exactly(record_one, record_two) }
    end

    context "when partition key in second partition" do
      let(:partition_key) { current_date + 1.day }

      it { is_expected.to contain_exactly(record_three) }
    end
  end
end
