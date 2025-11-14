# frozen_string_literal: true

require "spec_helper"

RSpec.describe "db:structure:dump", :structure_dump do
  subject do
    ActiveRecord.schema_format = :sql

    Rake::Task["db:schema:dump"].invoke
    File.read(File.expand_path("../../dummy/db/structure.sql", __FILE__))
  end

  context "when schema_exclude_partitions is true" do
    it { is_expected.to_not include("bigint_date_ranges_a") }
    it { is_expected.to include("bigint_date_ranges") }
  end

  context "when schema_exclude_partitions is false" do
    before { PgParty.config.schema_exclude_partitions = false }

    it { is_expected.to include("bigint_date_ranges_a") }
    it { is_expected.to include("bigint_date_ranges") }
  end
end
