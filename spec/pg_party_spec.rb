# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty do
  describe ".configure" do
    subject do
      described_class.configure do |c|
        c.caching = false
        c.caching_ttl = 60
      end

      described_class.config
    end

    its(:caching) { is_expected.to eq(false) }
    its(:caching_ttl) { is_expected.to eq(60) }
  end

  describe ".reset" do
    let!(:initial_config) { described_class.config }
    let!(:initial_cache) { described_class.cache }

    subject do
      described_class.reset
      described_class
    end

    its(:config) { is_expected.to_not eq(initial_config) }
    its(:cache) { is_expected.to_not eq(initial_cache) }
  end
end
