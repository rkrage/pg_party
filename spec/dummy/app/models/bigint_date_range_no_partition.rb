# frozen_string_literal: true

class BigintDateRangeNoPartition < ApplicationRecord
  range_partition_by { "(created_at::date)" }
end
