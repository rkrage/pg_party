# frozen_string_literal: true

require "spec_helper"

RSpec.describe BigintIntListDateRangeSubpartition do
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
    let(:id) { 1 }

    subject { described_class.create!(id: id, created_at: created_at) }

    context "when partition key in list" do
      its(:id) { is_expected.to be_a(Integer) }
      its(:id) { is_expected.to eq(id) }
      its(:created_at) { is_expected.to eq(created_at) }
    end

    context "when partition key outside list" do
      let(:id) { 5 }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::CheckViolation/)
      end
    end

    context "when subpartition key outside range" do
      let(:created_at) { current_time - 10.days }

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

    context 'include_subpartitions: true' do
      subject { described_class.partitions(include_subpartitions: true) }

      it { is_expected.to contain_exactly("#{table_name}_a", "#{table_name}_a_1", "#{table_name}_b") }
    end

    context 'config.include_subpartitions_in_partition_list = true' do
      before { PgParty.config.include_subpartitions_in_partition_list = true }
      after { PgParty.config.include_subpartitions_in_partition_list = false }

      it { is_expected.to contain_exactly("#{table_name}_a", "#{table_name}_a_1", "#{table_name}_b") }
    end
  end
end
