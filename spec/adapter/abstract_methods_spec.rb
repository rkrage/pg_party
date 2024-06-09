# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::Adapter::AbstractMethods do
  let(:adapter_class) do
    Class.new do
      include PgParty::Adapter::AbstractMethods
    end
  end

  subject(:adapter) { adapter_class.new }

  describe "#create_range_partition" do
    subject { adapter.create_range_partition("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#create_range_partition is not implemented")
    end
  end

  describe "#create_list_partition" do
    subject { adapter.create_list_partition("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#create_list_partition is not implemented")
    end
  end

  describe "#create_hash_partition" do
    subject { adapter.create_hash_partition("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#create_hash_partition is not implemented")
    end
  end

  describe "#create_range_partition_of" do
    subject { adapter.create_range_partition_of("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#create_range_partition_of is not implemented")
    end
  end

  describe "#create_list_partition_of" do
    subject { adapter.create_list_partition_of("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#create_list_partition_of is not implemented")
    end
  end

  describe "#create_hash_partition_of" do
    subject { adapter.create_hash_partition_of("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#create_hash_partition_of is not implemented")
    end
  end

  describe "#create_default_partition_of" do
    subject { adapter.create_default_partition_of("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#create_default_partition_of is not implemented")
    end
  end

  describe "#create_table_like" do
    subject { adapter.create_table_like("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#create_table_like is not implemented")
    end
  end

  describe "#attach_range_partition" do
    subject { adapter.attach_range_partition("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#attach_range_partition is not implemented")
    end
  end

  describe "#attach_list_partition" do
    subject { adapter.attach_list_partition("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#attach_list_partition is not implemented")
    end
  end

  describe "#attach_hash_partition" do
    subject { adapter.attach_hash_partition("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#attach_hash_partition is not implemented")
    end
  end

  describe "#attach_default_partition" do
    subject { adapter.attach_default_partition("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#attach_default_partition is not implemented")
    end
  end

  describe "#detach_partition" do
    subject { adapter.detach_partition("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#detach_partition is not implemented")
    end
  end

  describe "#parent_for_table_name" do
    subject { adapter.parent_for_table_name("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#parent_for_table_name is not implemented")
    end
  end

  describe "#partitions_for_table_name" do
    subject { adapter.partitions_for_table_name("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#partitions_for_table_name is not implemented")
    end
  end

  describe "#add_index_on_all_partitions" do
    subject { adapter.add_index_on_all_partitions("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#add_index_on_all_partitions is not implemented")
    end
  end

  describe "#table_partitioned?" do
    subject { adapter.table_partitioned?("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#table_partitioned? is not implemented")
    end
  end
end
