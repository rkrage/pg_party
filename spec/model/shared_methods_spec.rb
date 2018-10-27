# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::Model::SharedMethods do
  let(:decorator) { instance_double(PgParty::ModelDecorator) }

  before do
    allow(PgParty::ModelDecorator).to receive(:new).with(model).and_return(decorator)
  end

  subject(:model) do
    Class.new do
      extend PgParty::Model::SharedMethods
    end
  end

  describe ".reset_primary_key" do
    subject { model.reset_primary_key }

    it "delegates to decorator" do
      expect(decorator).to receive(:partition_primary_key)
      subject
    end
  end

  describe ".partition_table_exists?" do
    subject { model.table_exists? }

    it "delegates to decorator" do
      expect(decorator).to receive(:partition_table_exists?)
      subject
    end
  end

  describe ".partitions" do
    subject { model.partitions }

    it "delegates to decorator" do
      expect(decorator).to receive(:partitions)
      subject
    end
  end

  describe ".in_partition" do
    let(:partition) { "partition" }

    subject { model.in_partition(partition) }

    it "delegates to decorator" do
      expect(decorator).to receive(:in_partition).with(partition)
      subject
    end
  end

  describe ".partition_key_eq" do
    let(:value) { Date.current }

    subject { model.partition_key_eq(value) }

    it "delegates to decorator" do
      expect(decorator).to receive(:partition_key_eq).with(value)
      subject
    end
  end
end
