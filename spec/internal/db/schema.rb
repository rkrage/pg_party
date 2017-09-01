ActiveRecord::Schema.define do
  enable_extension "uuid-ossp"
  enable_extension "pgcrypto"

  create_master_partition :bigint_date_range do |t|
    t.timestamps
  end
end
