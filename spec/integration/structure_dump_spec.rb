# frozen_string_literal: true

require "spec_helper"

RSpec.describe "db:structure:dump" do
  let(:skip_test) { Rails.gem_version < Gem::Version.new("5.2") }

  subject do
    Rake::Task["db:structure:dump"].invoke
    File.read(File.expand_path("../../dummy/db/structure.sql", __FILE__))
  end

  it "does not include child partition tables" do
    skip "only supported in AR 5.2+" if skip_test

    expect(subject).to_not include("bigint_date_ranges_a")
  end

  it "does include parent partition tables" do
    skip "only supported in AR 5.2+" if skip_test

    expect(subject).to include("bigint_date_ranges")
  end

  it "includes child partition tables if the lookup fails" do
    skip "only supported in AR 5.2+" if skip_test

    allow_any_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      .to receive(:select_values)
      .and_raise("boom")

    expect(subject).to include("bigint_date_ranges_a")
  end
end
