require "spec_helper"

RSpec.describe PgParty::Model::ListMethods do
  let(:decorator) { instance_double(PgParty::ModelDecorator) }

  before do
    allow(PgParty::ModelDecorator).to receive(:new).with(model).and_return(decorator)
  end

  subject(:model) do
    Class.new do
      extend PgParty::Model::ListMethods
    end
  end

  describe ".create_partition" do
    let(:args) do
      {
        values: Date.current,
        name: "my_partition"
      }
    end

    subject { model.create_partition(args) }

    it "delegates to decorator" do
      expect(decorator).to receive(:create_list_partition).with(args)
      subject
    end
  end

  describe ".partition_key_in" do
    let(:values) { [Date.current, Date.tomorrow] }

    subject { model.partition_key_in(values) }

    it "delegates to decorator" do
      expect(decorator).to receive(:list_partition_key_in).with(values)
      subject
    end
  end
end
