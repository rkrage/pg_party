# frozen_string_literal: true

class BigintBooleanList < ApplicationRecord
  list_partition_by :some_bool
end
