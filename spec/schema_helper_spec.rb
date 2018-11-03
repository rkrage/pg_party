# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgParty::SchemaHelper do
  let(:table_name) { "table_name" }
  let(:adapter) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }
  let(:schema_cache) { instance_double(ActiveRecord::ConnectionAdapters::SchemaCache) }
  let(:table_exists_method) do
    if Rails.gem_version >= Gem::Version.new("5.0")
      "data_source_exists?"
    else
      "table_exists?"
    end
  end

  before do
    allow(ActiveRecord::Base).to receive(:connection).and_return(adapter)
    allow(adapter).to receive(:schema_cache).and_return(schema_cache)
    allow(schema_cache).to receive(table_exists_method)
  end

  describe ".table_exists?" do
    subject { described_class.table_exists?(table_name) }

    it "calls correct table exists method with table name" do
      expect(schema_cache).to receive(table_exists_method).with(table_name)
      subject
    end
  end
end
