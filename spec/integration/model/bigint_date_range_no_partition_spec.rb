# frozen_string_literal: true

require "spec_helper"

RSpec.describe BigintDateRangeNoPartition do
  let(:current_date) { Date.current }
  let(:current_time) { Time.current }
  let(:connection) { described_class.connection }
  let(:schema_cache) { connection.schema_cache }
  let(:table_name) { described_class.table_name }

  describe ".primary_key" do
    subject { described_class.primary_key }

    # some versions of rails recognize partition tables and
    # attempt to pull the nonexistent key from the parent table
    it { is_expected.to be_in([nil, "id"]) }
  end

  describe ".create" do
    let(:created_at) { current_time }

    subject { described_class.create!(created_at: created_at) }

    it "raises error" do
      expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::CheckViolation/)
    end
  end

  describe ".partitions" do
    subject { described_class.partitions }

    it { is_expected.to be_empty }
  end

  describe ".create_partition" do
    let(:start_range) { current_date }
    let(:end_range) { current_date + 1.day }
    let(:child_table_name) { "#{table_name}_a" }

    subject(:create_partition) do
      described_class.create_partition(
        start_range: start_range,
        end_range: end_range,
        name: child_table_name
      )
    end

    subject(:partitions) { described_class.partitions }

    before { described_class.partitions }
    after { connection.drop_table(child_table_name) }

    it "returns table name and adds it to partition list" do
      expect(create_partition).to eq(child_table_name)

      expect(partitions).to contain_exactly("#{table_name}_a")
    end
  end
end
