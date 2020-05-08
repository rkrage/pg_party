# frozen_string_literal: true

class BigintCustomIdIntRange < ApplicationRecord
  range_partition_by :some_int, :some_other_int
end
