# frozen_string_literal: true

module PgParty
  class Config
    attr_accessor :caching, :caching_ttl

    def initialize
      @caching = true
      @caching_ttl = -1
    end
  end
end
