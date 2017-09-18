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
    allow(PgParty::ModelInjector).to receive(:new).with(model, key).and_return(injector)
    allow(injector).to receive(:inject_range_methods)
    allow(injector).to receive(:inject_list_methods)
  end

  describe ".range_partition_by" do
    subject { model.range_partition_by(key) }

    it "delegates to injector" do
      expect(injector).to receive(:inject_range_methods)
      subject
    end
  end

  describe ".list_partition_by" do
    subject { model.list_partition_by(key) }

    it "delegates to injector" do
      expect(injector).to receive(:inject_list_methods)
      subject
    end
  end

  describe ".partitioned?" do
    subject { model.partitioned? }

    context "when partition key not defined" do
      it { is_expected.to eq(false) }
    end

    context "when partition key defined" do
      let(:block) { ->{ "blah" } }

      before { model.singleton_class.send(:define_method, :partition_key, &block) }

      it { is_expected.to eq(true) }
    end
  end
end
