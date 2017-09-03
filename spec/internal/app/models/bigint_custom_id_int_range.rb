class BigintCustomIdIntRange < ApplicationRecord
  self.primary_key = :some_id

  range_partition_by :some_int
end
