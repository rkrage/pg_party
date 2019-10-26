# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::Config do
  let(:instance) { described_class.new }

  describe "#caching" do
    subject { instance.caching }

    context "when defaulted" do
      it { is_expected.to eq(true) }
    end

    context "when overridden" do
      before { instance.caching = false }
      it { is_expected.to eq(false) }
    end
  end

  describe "#caching_ttl" do
    subject { instance.caching_ttl }

    context "when defaulted" do
      it { is_expected.to eq(-1) }
    end

    context "when overridden" do
      before { instance.caching_ttl = 60 }
      it { is_expected.to eq(60) }
    end
  end

  describe "#schema_exclude_partitions" do
    subject { instance.schema_exclude_partitions }

    context "when defaulted" do
      it { is_expected.to eq(true) }
    end

    context "when overridden" do
      before { instance.schema_exclude_partitions = false }
      it { is_expected.to eq(false) }
    end
  end
end
