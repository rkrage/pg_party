# frozen_string_literal: true

module PgParty
  class Config
    attr_accessor \
      :caching,
      :caching_ttl,
      :schema_exclude_partitions

    def initialize
      @caching = true
      @caching_ttl = -1
      @schema_exclude_partitions = true
    end
  end
end
