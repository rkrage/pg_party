require "spec_helper"

RSpec.describe PgParty::Model::ListMethods do
  let(:key) { "created_at::date" }
  let(:decorator) { instance_double(PgParty::ModelDecorator) }

  before do
    model.list_partition_by(key)
    allow(PgParty::ModelDecorator).to receive(:new).with(model).and_return(decorator)
  end

  subject(:model) do
    Class.new do
      extend PgParty::Model::Methods
    end
  end

  describe ".partition_key" do
    subject { model.partition_key }

    it { is_expected.to eq("created_at::date") }
  end

  describe ".partition_column" do
    subject { model.partition_column }

    context "when key has cast" do
      it { is_expected.to eq("created_at") }
    end

    context "when key does not have cast" do
      let(:key) { "created_at" }

      it { is_expected.to eq("created_at") }
    end
  end

  describe ".partition_cast" do
    subject { model.partition_cast }

    context "when key has cast" do
      it { is_expected.to eq("date") }
    end

    context "when key does not have cast" do
      let(:key) { "created_at" }

      it { is_expected.to be_nil }
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

  describe ".partition_key_eq" do
    let(:value) { Date.current }

    subject { model.partition_key_eq(value) }

    it "delegates to decorator" do
      expect(decorator).to receive(:partition_key_eq).with(value)
      subject
    end
  end
end
