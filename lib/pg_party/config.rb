# frozen_string_literal: true

module PgParty
  class Config
    attr_accessor \
      :caching,
      :caching_ttl,
      :schema_exclude_partitions,
      :create_template_tables,
      :create_with_primary_key,
      :include_subpartitions_in_partition_list

    def initialize
      @caching = true
      @caching_ttl = -1
      @schema_exclude_partitions = true
      @create_template_tables = true
      @create_with_primary_key = false
      @include_subpartitions_in_partition_list = false
    end
  end
end
