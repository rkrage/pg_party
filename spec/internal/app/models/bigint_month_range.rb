class BigintMonthRange < ApplicationRecord
  range_partition_by ->{ "EXTRACT(YEAR FROM created_at), EXTRACT(MONTH FROM created_at)" }
end
