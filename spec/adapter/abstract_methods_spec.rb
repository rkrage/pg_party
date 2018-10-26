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

  describe "#detach_partition" do
    subject { adapter.detach_partition("args") }

    it "raises not implemented error" do
      expect { subject }.to raise_error(RuntimeError, "#detach_partition is not implemented")
    end
  end
end
