# frozen_string_literal: true

class BigintCustomIdIntList < ApplicationRecord
  list_partition_by :some_int
end
