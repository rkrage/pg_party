# frozen_string_literal: true

ActiveRecord::Schema.define do
  execute("CREATE SCHEMA e9651f34")

  enable_extension "uuid-ossp"
  enable_extension "pgcrypto"

  create_range_partition :bigint_date_ranges, partition_key: ->{ "(created_at::date)" } do |t|
    t.timestamps null: false, precision: nil
  end

  create_range_partition_of \
    :bigint_date_ranges,
    name: :bigint_date_ranges_a,
    start_range: Date.today,
    end_range: Date.tomorrow

  create_range_partition_of \
    :bigint_date_ranges,
    name: :bigint_date_ranges_b,
    start_range: Date.tomorrow,
    end_range: Date.tomorrow + 1

  create_range_partition :bigint_month_ranges, partition_key: ->{ "EXTRACT(YEAR FROM created_at), EXTRACT(MONTH FROM created_at)" } do |t|
    t.timestamps null: false, precision: nil
    t.integer :some_indexed_column
  end

  add_index :bigint_month_ranges_template, :some_indexed_column

  # Rails 5+ supports expressions when creating indexes:
  #
  # add_index \
  #   :bigint_month_ranges_template,
  #   "EXTRACT(YEAR FROM created_at), EXTRACT(MONTH FROM created_at)",
  #   name: :bigint_month_ranges_created_at_month
  #
  # Rails 4.2 does not, so we're forced to use raw SQL:
  execute(<<-SQL)
    CREATE INDEX bigint_month_ranges_template_created_at
    ON bigint_month_ranges_template
    USING btree (EXTRACT(YEAR FROM created_at), EXTRACT(MONTH FROM created_at))
  SQL

  create_range_partition_of \
    :bigint_month_ranges,
    name: :bigint_month_ranges_a,
    start_range: [Date.today.year, Date.today.month],
    end_range: [(Date.today + 1.month).year, (Date.today + 1.month).month]

  create_range_partition_of \
    :bigint_month_ranges,
    name: :bigint_month_ranges_b,
    start_range: [(Date.today + 1.month).year, (Date.today + 1.month).month],
    end_range: [(Date.today + 2.months).year, (Date.today + 2.months).month]

  create_range_partition :bigint_custom_id_int_ranges, primary_key: :some_id, partition_key: [:some_int, :some_other_int] do |t|
    t.integer :some_int, null: false
    t.integer :some_other_int, null: false
  end

  create_range_partition_of \
    :bigint_custom_id_int_ranges,
    name: :bigint_custom_id_int_ranges_a,
    start_range: [0, 0],
    end_range: [10, 10]

  create_range_partition_of \
    :bigint_custom_id_int_ranges,
    name: :bigint_custom_id_int_ranges_b,
    start_range: [10, 10],
    end_range: [20, 20]

  create_range_partition :uuid_string_ranges, id: :uuid, partition_key: :some_string do |t|
    t.text :some_string, null: false
  end

  create_range_partition_of \
    :uuid_string_ranges,
    name: :uuid_string_ranges_a,
    start_range: "a",
    end_range: "l"

  create_range_partition_of \
    :uuid_string_ranges,
    name: :uuid_string_ranges_b,
    start_range: "l",
    end_range: "z"

  create_list_partition :bigint_boolean_lists, partition_key: :some_bool, template: false do |t|
    t.boolean :some_bool, default: true, null: false
  end

  create_list_partition_of \
    :bigint_boolean_lists,
    name: :bigint_boolean_lists_a,
    values: true

  create_list_partition_of \
    :bigint_boolean_lists,
    name: :bigint_boolean_lists_b,
    values: false

  create_list_partition :bigint_custom_id_int_lists, primary_key: :some_id, partition_key: :some_int do |t|
    t.integer :some_int, null: false
  end

  create_list_partition_of \
    :bigint_custom_id_int_lists,
    name: :bigint_custom_id_int_lists_a,
    values: [1, 2]

  create_list_partition_of \
    :bigint_custom_id_int_lists,
    name: :bigint_custom_id_int_lists_b,
    values: [3, 4]

  create_list_partition :uuid_string_lists, id: :uuid, partition_key: :some_string do |t|
    t.text :some_string, null: false
  end

  create_list_partition_of \
    :uuid_string_lists,
    name: :uuid_string_lists_a,
    values: ["a", "b"]

  create_list_partition_of \
    :uuid_string_lists,
    name: :uuid_string_lists_b,
    values: ["c", "d"]

  create_list_partition :no_pk_substring_lists, id: false, partition_key: ->{ "LEFT(some_string, 1)" } do |t|
    t.text :some_string, null: false
  end

  create_list_partition_of \
    :no_pk_substring_lists,
    name: :no_pk_substring_lists_a,
    values: ["a", "b"]

  create_list_partition_of \
    :no_pk_substring_lists,
    name: :no_pk_substring_lists_b,
    values: ["c", "d"]

  create_range_partition :bigint_date_range_no_partitions, partition_key: ->{ "(created_at::date)" } do |t|
    t.timestamps null: false, precision: nil
  end
end
