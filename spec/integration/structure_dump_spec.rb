# frozen_string_literal: true

require "spec_helper"

RSpec.describe "db:structure:dump" do
  subject do
    ActiveRecord::Base.schema_format = :sql
    Rake::Task["db:structure:dump"].invoke
    File.read(File.expand_path("../../dummy/db/structure.sql", __FILE__))
  end

  context "when schema_exclude_partitions is true" do
    it { is_expected.to_not include("bigint_date_ranges_a") }
    it { is_expected.to include("bigint_date_ranges") }

    context "when partition lookup fails" do
      before do
        allow_any_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
          .to receive(:select_values)
          .and_raise("boom")
      end

      it { is_expected.to include("bigint_date_ranges_a") }
    end
  end

  context "when schema_exclude_partitions is false" do
    before { PgParty.config.schema_exclude_partitions = false }

    it { is_expected.to include("bigint_date_ranges_a") }
    it { is_expected.to include("bigint_date_ranges") }
  end
end
