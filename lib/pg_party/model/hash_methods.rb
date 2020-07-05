# frozen_string_literal: true

require "pg_party/model_decorator"
require "ruby2_keywords"

module PgParty
  module Model
    module HashMethods
      ruby2_keywords def create_partition(*args)
        PgParty::ModelDecorator.new(self).create_hash_partition(*args)
      end

      ruby2_keywords def partition_key_in(*args)
        PgParty::ModelDecorator.new(self).hash_partition_key_in(*args)
      end
    end
  end
end
