require "spec_helper"

RSpec.describe ActiveRecord::ConnectionAdapters::AbstractAdapter do
  let(:custom_adapter_instance) { custom_adapter_class.new }
  let(:custom_adapter_class) do
    Class.new(ActiveRecord::ConnectionAdapters::AbstractAdapter) do
      def initialize
        # so we can create an adapter instance without connection config
      end
    end
  end

  describe "#create_master_partition" do
    let(:table_name) { SecureRandom.hex }
    let(:keyword_args) { {} }
    let(:block) { ->{} }

    subject { ActiveRecord::Base.connection.create_master_partition(table_name, keyword_args, &block) }

    context "with non-postgres adapter" do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance)
      end

      it "raises not implemented error" do
        expect { subject }.to raise_error(NotImplementedError, "#create_master_partition is not implemented")
      end
    end

    context "with postgres adapter" do
      # TODO: write tests
    end
  end

  describe "#create_child_partition" do
    let(:parent_table_name) { SecureRandom.hex }
    let(:current_date) { Date.current }
    let(:start_range) { current_date }
    let(:end_range) { current_date + 1.month }
    let(:additional_options) { {} }
    let(:keyword_args) do
      additional_options.merge(
        start_range: start_range,
        end_range: end_range
      )
    end

    subject { ActiveRecord::Base.connection.create_child_partition(parent_table_name, keyword_args) }

    context "with non-postgres adapter" do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance)
      end

      it "raises not implemented error" do
        expect { subject }.to raise_error(NotImplementedError, "#create_child_partition is not implemented")
      end
    end

    context "with postgres adapter" do
      # TODO: write tests
    end
  end
end
