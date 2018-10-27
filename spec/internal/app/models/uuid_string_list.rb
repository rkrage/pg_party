# frozen_string_literal: true

class UuidStringList < ApplicationRecord
  list_partition_by :some_string
end
