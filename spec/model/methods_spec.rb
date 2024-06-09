# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::Model::Methods do
  let(:key) { "created_at::date" }
  let(:injector) { instance_double(PgParty::ModelInjector) }

  subject(:model) do
    Class.new do
      extend PgParty::Model::Methods
    end
  end

  before do
    allow(PgParty::ModelInjector).to receive(:new).and_return(injector)
    allow(injector).to receive(:inject_range_methods)
    allow(injector).to receive(:inject_list_methods)
    allow(injector).to receive(:inject_hash_methods)
  end

  describe ".range_partition_by" do
    context "when partition key provided as argument" do
      subject { model.range_partition_by(key) }

      it "initializes injector with model and key" do
        expect(PgParty::ModelInjector).to receive(:new).with(model, key)
        subject
      end

      it "delegates to injector" do
        expect(injector).to receive(:inject_range_methods)
        subject
      end
    end

    context "when partition key provided as block" do
      let(:key_as_block) { -> { key } }

      subject { model.range_partition_by(&key_as_block) }

      it "initializes injector with model and block" do
        expect(PgParty::ModelInjector).to receive(:new) do |m, &blk|
          expect(m).to eq(model)
          expect(blk).to eq(blk)
          injector
        end

        subject
      end

      it "delegates to injector" do
        expect(injector).to receive(:inject_range_methods)
        subject
      end
    end
  end

  describe ".list_partition_by" do
    context "when partition key provided as argument" do
      subject { model.list_partition_by(key) }

      it "initializes injector with model and key" do
        expect(PgParty::ModelInjector).to receive(:new).with(model, key)
        subject
      end

      it "delegates to injector" do
        expect(injector).to receive(:inject_list_methods)
        subject
      end
    end

    context "when partition key provided as block" do
      let(:key_as_block) { -> { key } }

      subject { model.list_partition_by(&key_as_block) }

      it "initializes injector with model and block" do
        expect(PgParty::ModelInjector).to receive(:new) do |m, &blk|
          expect(m).to eq(model)
          expect(blk).to eq(blk)
          injector
        end

        subject
      end

      it "delegates to injector" do
        expect(injector).to receive(:inject_list_methods)
        subject
      end
    end
  end

  describe ".hash_partition_by" do
    context "when partition key provided as argument" do
      subject { model.hash_partition_by(key) }

      it "initializes injector with model and key" do
        expect(PgParty::ModelInjector).to receive(:new).with(model, key)
        subject
      end

      it "delegates to injector" do
        expect(injector).to receive(:inject_hash_methods)
        subject
      end
    end

    context "when partition key provided as block" do
      let(:key_as_block) { -> { key } }

      subject { model.hash_partition_by(&key_as_block) }

      it "initializes injector with model and block" do
        expect(PgParty::ModelInjector).to receive(:new) do |m, &blk|
          expect(m).to eq(model)
          expect(blk).to eq(blk)
          injector
        end

        subject
      end

      it "delegates to injector" do
        expect(injector).to receive(:inject_hash_methods)
        subject
      end
    end
  end

  describe ".partitioned?" do
    subject { model.partitioned? }

    context "when partition key not defined" do
      it { is_expected.to eq(false) }
    end

    context "when partition key defined" do
      let(:block) { -> { "blah" } }

      before { model.singleton_class.send(:define_method, :partition_key, &block) }

      it { is_expected.to eq(true) }
    end
  end
end
