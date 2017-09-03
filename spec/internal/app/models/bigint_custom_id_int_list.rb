class BigintCustomIdIntList < ApplicationRecord
  self.primary_key = :some_id

  list_partition_by :some_int
end
