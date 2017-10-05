require "spec_helper"

RSpec.describe PgParty::ModelDecorator do
  let(:table_name) { :parent }
  let(:partitions) { ["a", "b"] }
  let(:primary_key) { :id }
  let(:partition_key) { :id }
  let(:arel_node) { double }
  let(:adapter) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }

  let(:model) do
    Class.new(ActiveRecord::Base) do
      class_attribute \
        :partition_key,
        :partition_column,
        :partition_cast,
        :cached_partitions,
        instance_accessor: false
    end
  end

  before do
    model.partition_key = partition_key
    model.primary_key = primary_key
    model.table_name = table_name
    model.cached_partitions = partitions

    allow(model).to receive(:where)
    allow(model).to receive(:connection).and_return(adapter)

    allow(adapter).to receive(:create_range_partition_of)
    allow(adapter).to receive(:create_list_partition_of)
    allow(adapter).to receive(:select_values).and_return(partitions)
    allow(adapter).to receive(:quote) { |value| "'#{value}'" }

    # stubbing arel is complex, so this is tested in the integration specs
    allow(decorator).to receive(:partition_key_as_arel).and_return(arel_node)

    allow(arel_node).to receive(:eq).and_return(arel_node)
    allow(arel_node).to receive(:gteq).and_return(arel_node)
    allow(arel_node).to receive(:lt).and_return(arel_node)
    allow(arel_node).to receive(:and).and_return(arel_node)
    allow(arel_node).to receive(:in).and_return(arel_node)

    allow(ActiveRecord::Base).to receive(:all)
  end

  subject(:decorator) { described_class.new(model) }

  describe "#in_partition" do
    subject { decorator.in_partition("child") }

    it "calls all on anonymous model" do
      expect(ActiveRecord::Base).to receive(:all)
      subject
    end
  end

  describe "#partition_key_eq" do
    subject { decorator.partition_key_eq(1) }

    it "calls eq on arel node" do
      expect(arel_node).to receive(:eq).with(1)
      subject
    end

    it "calls where with arel node" do
      expect(model).to receive(:where).with(arel_node)
      subject
    end
  end

  describe "#range_partition_key_in" do
    subject { decorator.range_partition_key_in(1, 10) }

    it "calls gteq on arel node" do
      expect(arel_node).to receive(:gteq).with(1)
      subject
    end

    it "calls and on arel node" do
      expect(arel_node).to receive(:and).with(arel_node)
      subject
    end

    it "calls lt on arel node" do
      expect(arel_node).to receive(:lt).with(10)
      subject
    end

    it "calls where with arel node" do
      expect(model).to receive(:where).with(arel_node)
      subject
    end
  end

  describe "#list_partition_key_in" do
    context "with array params" do
      subject { decorator.list_partition_key_in([1, 2]) }

      it "calls in on arel node" do
        expect(arel_node).to receive(:in).with([1, 2])
        subject
      end

      it "calls where with arel node" do
        expect(model).to receive(:where).with(arel_node)
        subject
      end
    end

    context "with param list" do
      subject { decorator.list_partition_key_in(1, 2) }

      it "calls in on arel node" do
        expect(arel_node).to receive(:in).with([1, 2])
        subject
      end

      it "calls where with arel node" do
        expect(model).to receive(:where).with(arel_node)
        subject
      end
    end
  end

  describe "#partitions" do
    subject { decorator.partitions }

    context "when cached_partitions nil" do
      before { model.cached_partitions = nil }

      it { is_expected.to eq(partitions) }

      it "calls select_values on adapter" do
        expect(adapter).to receive(:select_values).with(/'#{table_name}'/)
        subject
      end

      it "sets cached_partitions" do
        subject
        expect(model.cached_partitions).to eq(partitions)
      end

    end

    context "when cached_partitions present" do
      it { is_expected.to eq(partitions) }

      it "does not call select_values on adapter" do
        expect(adapter).to_not receive(:select_values)
        subject
      end
    end
  end

  describe "#create_range_partition" do
    subject { decorator.create_range_partition(start_range: 1, end_range: 10, name: :child) }

    it "calls create_range_partition on adapter" do
      expect(adapter).to receive(:create_range_partition_of).with(
        table_name.to_s,
        start_range: 1,
        end_range: 10,
        primary_key: primary_key.to_s,
        partition_key: partition_key,
        name: :child
      )

      subject
    end

    it "resets cached_partitions" do
      subject
      expect(model.cached_partitions).to be_nil
    end
  end

  describe "#create_list_partition" do
    subject { decorator.create_list_partition(values: [1, 2, 3], name: :child) }

    it "calls create_range_partition on adapter" do
      expect(adapter).to receive(:create_list_partition_of).with(
        table_name.to_s,
        values: [1, 2, 3],
        primary_key: primary_key.to_s,
        partition_key: partition_key,
        name: :child
      )

      subject
    end

    it "resets cached_partitions" do
      subject
      expect(model.cached_partitions).to be_nil
    end
  end
end
