# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::Adapter::PostgreSQLMethods do
  let(:decorator) { instance_double(PgParty::AdapterDecorator) }
  let(:adapter_class) do
    Class.new do
      include PgParty::Adapter::PostgreSQLMethods
    end
  end

  before do
    allow(PgParty::AdapterDecorator).to receive(:new).with(adapter).and_return(decorator)
  end

  subject(:adapter) { adapter_class.new }

  describe "#create_range_partition" do
    subject { adapter.create_range_partition(:parent, partition_key: :id) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_range_partition).with(:parent, partition_key: :id)
      subject
    end
  end

  describe "#create_list_partition" do
    subject { adapter.create_list_partition(:parent, partition_key: :id) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_list_partition).with(:parent, partition_key: :id)
      subject
    end
  end

  describe "#create_hash_partition" do
    subject { adapter.create_hash_partition(:parent, partition_key: :id) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_hash_partition).with(:parent, partition_key: :id)
      subject
    end
  end

  describe "#create_range_partition_of" do
    subject { adapter.create_range_partition_of(:parent, start_range: 1, end_range: 10) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_range_partition_of).with(:parent, start_range: 1, end_range: 10)
      subject
    end
  end

  describe "#create_list_partition_of" do
    subject { adapter.create_list_partition_of(:parent, values: [1, 2, 3]) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_list_partition_of).with(:parent, values: [1, 2, 3])
      subject
    end
  end

  describe "#create_hash_partition_of" do
    subject { adapter.create_hash_partition_of(:parent, modulus: 2, remainder: 0) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_hash_partition_of).with(:parent, modulus: 2, remainder: 0)
      subject
    end
  end

  describe "#create_default_partition_of" do
    subject { adapter.create_default_partition_of(:parent) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_default_partition_of).with(:parent)
      subject
    end
  end

  describe "#create_table_like" do
    subject { adapter.create_table_like(:table_a, :table_b) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_table_like).with(:table_a, :table_b)
      subject
    end
  end

  describe "#attach_range_partition" do
    subject { adapter.attach_range_partition(:parent, :child, start_range: 1, end_range: 10) }

    it "delegates to decorator" do
      expect(decorator).to receive(:attach_range_partition).with(:parent, :child, start_range: 1, end_range: 10)
      subject
    end
  end

  describe "#attach_list_partition" do
    subject { adapter.attach_list_partition(:parent, :child, values: [1, 2, 3]) }

    it "delegates to decorator" do
      expect(decorator).to receive(:attach_list_partition).with(:parent, :child, values: [1, 2, 3])
      subject
    end
  end

  describe "#attach_hash_partition" do
    subject { adapter.attach_hash_partition(:parent, :child, modulus: 2, remainder: 0) }

    it "delegates to decorator" do
      expect(decorator).to receive(:attach_hash_partition).with(:parent, :child, modulus: 2, remainder: 0)
      subject
    end
  end

  describe "#attach_default_partition" do
    subject { adapter.attach_default_partition(:parent, :child) }

    it "delegates to decorator" do
      expect(decorator).to receive(:attach_default_partition).with(:parent, :child)
      subject
    end
  end

  describe "#detach_partition" do
    subject { adapter.detach_partition(:parent, :child) }

    it "delegates to decorator" do
      expect(decorator).to receive(:detach_partition).with(:parent, :child)
      subject
    end
  end

  describe "#parent_for_table_name" do
    subject { adapter.parent_for_table_name(:table_name, traverse: true) }

    it "delegates to decorator" do
      expect(decorator).to receive(:parent_for_table_name).with(:table_name, traverse: true)
      subject
    end
  end

  describe "#partitions_for_table_name" do
    subject { adapter.partitions_for_table_name(:table_name, include_subpartitions: true) }

    it "delegates to decorator" do
      expect(decorator).to receive(:partitions_for_table_name).with(:table_name, include_subpartitions: true)
      subject
    end
  end

  describe "#add_index_on_all_partitions" do
    subject { adapter.add_index_on_all_partitions(:table_name, [:columns], unique: true, in_threads: 2) }

    it "delegates to decorator" do
      expect(decorator).to receive(:add_index_on_all_partitions)
                             .with(:table_name, [:columns], unique: true, in_threads: 2)
      subject
    end
  end
end
