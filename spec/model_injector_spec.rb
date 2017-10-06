require "spec_helper"

RSpec.describe PgParty::ModelInjector do
  let(:key) { "created_at::date" }
  let(:model) { Class.new }

  subject(:injector) { described_class.new(model, key) }
  subject(:inject_range_methods) { injector.inject_range_methods }
  subject(:inject_list_methods) { injector.inject_list_methods }

  before { allow(model).to receive(:extend).and_call_original }

  describe "#inject_range_methods" do
    subject { inject_range_methods }

    it "extends range methods" do
      expect(model).to receive(:extend).with(PgParty::Model::RangeMethods)
      subject
    end

    it "extends shared methods" do
      expect(model).to receive(:extend).with(PgParty::Model::SharedMethods)
      subject
    end

    describe "model" do
      subject do
        inject_range_methods
        model
      end

      its(:partition_key) { is_expected.to eq("created_at::date") }
      its(:partition_column) { is_expected.to eq("created_at") }
      its(:partition_cast) { is_expected.to eq("date") }
      its(:cached_partitions) { is_expected.to be_nil }
    end
  end

  describe "#inject_list_methods" do
    subject { inject_list_methods }

    it "extends range methods" do
      expect(model).to receive(:extend).with(PgParty::Model::ListMethods)
      subject
    end

    it "extends shared methods" do
      expect(model).to receive(:extend).with(PgParty::Model::SharedMethods)
      subject
    end

    describe "model" do
      subject do
        inject_list_methods
        model
      end

      its(:partition_key) { is_expected.to eq("created_at::date") }
      its(:partition_column) { is_expected.to eq("created_at") }
      its(:partition_cast) { is_expected.to eq("date") }
      its(:cached_partitions) { is_expected.to be_nil }
    end
  end
end
