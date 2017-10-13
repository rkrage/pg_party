class BigintCustomIdIntList < ApplicationRecord
  list_partition_by :some_int
end
