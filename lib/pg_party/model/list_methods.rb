# frozen_string_literal: true

require "pg_party/model_decorator"
require "ruby2_keywords"

module PgParty
  module Model
    module ListMethods
      ruby2_keywords def create_partition(*args)
        PgParty::ModelDecorator.new(self).create_list_partition(*args)
      end

      ruby2_keywords def create_default_partition(*args)
        PgParty::ModelDecorator.new(self).create_default_partition(*args)
      end

      ruby2_keywords def partition_key_in(*args)
        PgParty::ModelDecorator.new(self).list_partition_key_in(*args)
      end
    end
  end
end
