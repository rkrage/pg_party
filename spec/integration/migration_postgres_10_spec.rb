# frozen_string_literal: true

require "spec_helper"

# Integration tests run only on Postgres 10
RSpec.describe ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, if: PgVersionHelper.postgres_10? do
  let(:table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:child_table_name) { "t_#{SecureRandom.hex(6)}" }
  let(:table_like_name) { "t_#{SecureRandom.hex(6)}" }

  before do
    ActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore
  end

  after do
    ActiveRecord::Base.primary_key_prefix_type = nil

    adapter.execute("DROP TABLE IF EXISTS #{table_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{child_table_name} CASCADE")
    adapter.execute("DROP TABLE IF EXISTS #{table_like_name} CASCADE")
  end

  subject(:adapter) { ActiveRecord::Base.connection }

  subject(:create_hash_partition) do
    adapter.create_hash_partition(
      table_name,
      partition_key: "#{table_name}_id",
      id: :serial
    )
  end

  subject(:create_default_partition_of) do
    adapter.create_default_partition_of(table_name)
  end

  describe "#create_hash_partition" do
    subject { create_hash_partition }

    it 'raises error' do
      expect { subject }.to raise_error NotImplementedError,
                                        'Hash partitions are only available in Postgres 11 or higher'
    end
  end

  describe "#create_default_partition_of" do
    subject { create_default_partition_of }

    it 'raises error' do
      expect { subject }.to raise_error NotImplementedError,
                                        'Default partitions are only available in Postgres 11 or higher'
    end
  end
end
