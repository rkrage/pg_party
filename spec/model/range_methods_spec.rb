# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::Model::RangeMethods do
  let(:decorator) { instance_double(PgParty::ModelDecorator) }

  before do
    allow(PgParty::ModelDecorator).to receive(:new).with(model).and_return(decorator)
  end

  subject(:model) do
    Class.new do
      extend PgParty::Model::RangeMethods
    end
  end

  describe ".create_partition" do
    let(:options) do
      {
        start_range: Date.current,
        end_range: Date.tomorrow,
        name: "my_partition"
      }
    end

    subject { model.create_partition(**options) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_range_partition).with(options)
      subject
    end
  end

  describe ".partition_key_in" do
    let(:start_range) { Date.current }
    let(:end_range)   { Date.tomorrow }

    subject { model.partition_key_in(start_range, end_range) }

    it "delegates to decorator" do
      expect(decorator).to receive(:range_partition_key_in).with(start_range, end_range)
      subject
    end
  end
end
