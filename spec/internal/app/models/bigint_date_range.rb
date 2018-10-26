class BigintDateRange < ApplicationRecord
  range_partition_by ->{ "(created_at::date)" }
end
