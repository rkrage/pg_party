# frozen_string_literal: true

class NoPkSubstringList < ApplicationRecord
  list_partition_by { "LEFT(some_string, 1)" }
end
