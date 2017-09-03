class UuidStringRange < ApplicationRecord
  range_partition_by :some_string
end
