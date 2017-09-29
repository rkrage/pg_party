require "spec_helper"

RSpec.describe PgParty::ModelDecorator do
  let(:table_name) { :parent }
  let(:primary_key) { :id }
  let(:partition_key) { :id }
  let(:arel_node) { double }
  let(:adapter) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }

  let(:model) do
    Class.new(ActiveRecord::Base) do
      attr_reader :partition_key
    end
  end

  before do
    allow(model).to receive(:partition_key).and_return(partition_key)
    allow(model).to receive(:primary_key).and_return(primary_key)
    allow(model).to receive(:table_name).and_return(table_name)
    allow(model).to receive(:where)
    allow(model).to receive(:connection).and_return(adapter)

    allow(adapter).to receive(:create_range_partition_of)
    allow(adapter).to receive(:create_list_partition_of)

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

  describe "#create_range_partition" do
    subject { decorator.create_range_partition(start_range: 1, end_range: 10, name: :child) }

    it "calls create_range_partition on adapter" do
      expect(adapter).to receive(:create_range_partition_of).with(
        table_name,
        start_range: 1,
        end_range: 10,
        primary_key: primary_key,
        partition_key: partition_key,
        name: :child
      )

      subject
    end
  end

  describe "#create_list_partition" do
    subject { decorator.create_list_partition(values: [1, 2, 3], name: :child) }

    it "calls create_range_partition on adapter" do
      expect(adapter).to receive(:create_list_partition_of).with(
        table_name,
        values: [1, 2, 3],
        primary_key: primary_key,
        partition_key: partition_key,
        name: :child
      )

      subject
    end
  end
end
