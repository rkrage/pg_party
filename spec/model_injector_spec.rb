# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::ModelInjector do
  let(:key) { "created_at" }
  let(:model) { Class.new }

  subject(:injector) { described_class.new(model, key) }
  subject(:inject_range_methods) { injector.inject_range_methods }
  subject(:inject_list_methods) { injector.inject_list_methods }

  before { allow(model).to receive(:extend).and_call_original }

  describe "#inject_range_methods" do
    subject { inject_range_methods }

    context "when key is a string" do
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

        its(:partition_key) { is_expected.to eq("created_at") }
        its(:complex_partition_key) { is_expected.to eq(false) }
      end
    end

    context "when key is a proc" do
      let(:key) { ->{ "created_at::date" } }

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
        its(:complex_partition_key) { is_expected.to eq(true) }
      end
    end
  end

  describe "#inject_list_methods" do
    subject { inject_list_methods }

    context "when key is a string" do
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

        its(:partition_key) { is_expected.to eq("created_at") }
        its(:complex_partition_key) { is_expected.to eq(false) }
      end
    end

    context "when key is a proc" do
      let(:key) { ->{ "created_at::date" } }

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
        its(:complex_partition_key) { is_expected.to eq(true) }
      end
    end
  end
end
