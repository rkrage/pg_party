# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::Model::HashMethods do
  let(:decorator) { instance_double(PgParty::ModelDecorator) }

  before do
    allow(PgParty::ModelDecorator).to receive(:new).with(model).and_return(decorator)
  end

  subject(:model) do
    Class.new do
      extend PgParty::Model::HashMethods
    end
  end

  describe ".create_partition" do
    let(:args) do
      {
        modulus: 2,
        remainder: 0,
        name: "my_partition"
      }
    end

    subject { model.create_partition(args) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_hash_partition).with(args)
      subject
    end
  end

  describe ".partition_key_in" do
    let(:values) { [2, SecureRandom.uuid] }

    subject { model.partition_key_in(values) }

    it "delegates to decorator" do
      expect(decorator).to receive(:hash_partition_key_in).with(values)
      subject
    end
  end
end
