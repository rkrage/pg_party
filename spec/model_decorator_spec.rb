require "spec_helper"

RSpec.describe PgParty::ModelDecorator do
  let(:table_name) { "parent" }
  let(:model_name) { "foo" }
  let(:partitions) { ["a", "b"] }
  let(:primary_key) { :id }
  let(:partition_key) { :id }
  let(:complex_partition_key) { false }
  let(:arel_node) { double }
  let(:adapter) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }
  let(:schema_cache) { instance_double(ActiveRecord::ConnectionAdapters::SchemaCache) }
  let(:child_class) { class_double(ActiveRecord::Base) }
  let(:base_class) { model }
  let(:table_exists_method) do
    if Rails.gem_version >= Gem::Version.new("5.0")
      "data_source_exists?"
    else
      "table_exists?"
    end
  end

  let(:model) do
    Class.new(ActiveRecord::Base) do
      class_attribute \
        :partition_key,
        :complex_partition_key,
        instance_accessor: false

      def self.define_attribute_methods
        # needed to stub rails 4.2 models
      end
    end
  end

  before do
    model.partition_key = partition_key
    model.complex_partition_key = complex_partition_key
    model.table_name = table_name
    model.primary_key = primary_key

    allow(model).to receive(:where)
    allow(model).to receive(:connection).and_return(adapter)
    allow(model).to receive(:get_primary_key)
    allow(model).to receive(:base_class).and_return(base_class)
    allow(model).to receive(:name).and_return(model_name)

    allow(adapter).to receive(:create_range_partition_of)
    allow(adapter).to receive(:create_list_partition_of)
    allow(adapter).to receive(:select_values).and_return(partitions)
    allow(adapter).to receive(:quote) { |value| "'#{value}'" }
    allow(adapter).to receive(:schema_cache).and_return(schema_cache)

    allow(schema_cache).to receive(table_exists_method)

    # stubbing arel is complex, so this is tested in the integration specs
    allow(decorator).to receive(:partition_key_as_arel).and_return(arel_node)
    allow(Class).to receive(:new).with(model).and_return(child_class)

    allow(arel_node).to receive(:eq).and_return(arel_node)
    allow(arel_node).to receive(:gteq).and_return(arel_node)
    allow(arel_node).to receive(:lt).and_return(arel_node)
    allow(arel_node).to receive(:and).and_return(arel_node)
    allow(arel_node).to receive(:in).and_return(arel_node)

    allow(child_class).to receive(:all)
    allow(child_class).to receive(:get_primary_key)

    allow(PgParty::Cache).to receive(:fetch_model).and_wrap_original { |*_, &blk| blk.call }
    allow(PgParty::Cache).to receive(:fetch_partitions).and_wrap_original { |*_, &blk| blk.call }
  end

  subject(:decorator) { described_class.new(model) }

  describe "#partition_primary_key" do
    subject { decorator.partition_primary_key }

    context "when base_class is a different class" do
      let(:base_class) { class_double(ActiveRecord::Base, primary_key: nil) }

      it "calls primary_key on base_class" do
        expect(base_class).to receive(:primary_key).with(no_args)
        subject
      end
    end

    context "when partitions present" do
      it "calls get_primary_key on anonymous model" do
        expect(child_class).to receive(:get_primary_key).with("foo")
        subject
      end
    end

    context "when partitions not present" do
      let(:partitions) { [] }

      it "calls get_primary_key on model" do
        expect(model).to receive(:get_primary_key).with("foo")
        subject
      end
    end
  end

  describe "#partition_table_exists?" do
    subject { decorator.partition_table_exists? }

    context "when partitions present" do
      it "calls table exists method with partition table name" do
        expect(schema_cache).to receive(table_exists_method).with("a")
        subject
      end
    end

    context "when partitions not present" do
      let(:partitions) { [] }

      it "calls table exists method with table name" do
        expect(schema_cache).to receive(table_exists_method).with("parent")
        subject
      end
    end
  end

  describe "#in_partition" do
    subject { decorator.in_partition("child") }

    it "calls fetch_model on cache" do
      expect(PgParty::Cache).to receive(:fetch_model).with(kind_of(Numeric), "child")
      subject
    end

    it "calls new on class" do
      expect(Class).to receive(:new).with(model)
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

    context "when complex_partition_key is true" do
      let(:complex_partition_key) { true }

      it "raises error" do
        expect { subject }.to raise_error(RuntimeError, "#partition_key_eq not available for complex partition keys")
      end
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

    context "when complex_partition_key is true" do
      let(:complex_partition_key) { true }

      it "raises error" do
        expect { subject }.to raise_error(RuntimeError, "#partition_key_in not available for complex partition keys")
      end
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

    context "when complex_partition_key is true" do
      let(:complex_partition_key) { true }

      subject { decorator.list_partition_key_in([1, 2]) }

      it "raises error" do
        expect { subject }.to raise_error(RuntimeError, "#partition_key_in not available for complex partition keys")
      end
    end
  end

  describe "#partitions" do
    subject { decorator.partitions }

    it { is_expected.to eq(partitions) }

    it "calls fetch_partitions on cache" do
      expect(PgParty::Cache).to receive(:fetch_partitions).with(kind_of(Numeric))
      subject
    end

    it "calls select_values on adapter" do
      expect(adapter).to receive(:select_values).with(/'#{table_name}'/)
      subject
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

    context "when complex_partition_key is true" do
      let(:complex_partition_key) { true }

      it "calls create_range_partition on adapter with proc partition_key" do
        expect(adapter).to receive(:create_range_partition_of).with(
          table_name.to_s,
          start_range: 1,
          end_range: 10,
          primary_key: primary_key.to_s,
          partition_key: kind_of(Proc),
          name: :child
        )

        subject
      end
    end
  end

  describe "#create_list_partition" do
    subject { decorator.create_list_partition(values: [1, 2, 3], name: :child) }

    it "calls create_list_partition on adapter" do
      expect(adapter).to receive(:create_list_partition_of).with(
        table_name.to_s,
        values: [1, 2, 3],
        primary_key: primary_key.to_s,
        partition_key: partition_key,
        name: :child
      )

      subject
    end

    context "when complex_partition_key is true" do
      let(:complex_partition_key) { true }

      it "calls create_list_partition on adapter with proc partition key" do
        expect(adapter).to receive(:create_list_partition_of).with(
          table_name.to_s,
          values: [1, 2, 3],
          primary_key: primary_key.to_s,
          partition_key: kind_of(Proc),
          name: :child
        )

        subject
      end
    end
  end
end
