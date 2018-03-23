ActiveRecord::Schema.define do
  execute("CREATE SCHEMA e9651f34")

  enable_extension "uuid-ossp"
  enable_extension "pgcrypto"

  create_range_partition :bigint_date_ranges, partition_key: "created_at::date" do |t|
    t.timestamps null: false
  end

  create_range_partition_of :bigint_date_ranges,
    name: :bigint_date_ranges_a,
    partition_key: "created_at::date",
    start_range: Date.today,
    end_range: Date.tomorrow

  create_range_partition_of :bigint_date_ranges,
    name: :bigint_date_ranges_b,
    partition_key: "created_at::date",
    start_range: Date.tomorrow,
    end_range: Date.tomorrow + 1

  create_range_partition :bigint_custom_id_int_ranges, primary_key: :some_id, partition_key: :some_int do |t|
    t.integer :some_int, null: false
  end

  create_range_partition_of :bigint_custom_id_int_ranges,
    name: :bigint_custom_id_int_ranges_a,
    primary_key: :some_id,
    partition_key: :some_int,
    start_range: 0,
    end_range: 10

  create_range_partition_of :bigint_custom_id_int_ranges,
    name: :bigint_custom_id_int_ranges_b,
    primary_key: :some_id,
    partition_key: :some_int,
    start_range: 10,
    end_range: 20

  create_range_partition :uuid_string_ranges, id: :uuid, partition_key: :some_string do |t|
    t.text :some_string, null: false
  end

  create_range_partition_of :uuid_string_ranges,
    name: :uuid_string_ranges_a,
    partition_key: :some_string,
    start_range: "a",
    end_range: "l"

  create_range_partition_of :uuid_string_ranges,
    name: :uuid_string_ranges_b,
    partition_key: :some_string,
    start_range: "l",
    end_range: "z"

  create_list_partition :bigint_boolean_lists, partition_key: :some_bool do |t|
    t.boolean :some_bool, default: true, null: false
  end

  create_list_partition_of :bigint_boolean_lists,
    name: :bigint_boolean_lists_a,
    partition_key: :some_bool,
    values: true

  create_list_partition_of :bigint_boolean_lists,
    name: :bigint_boolean_lists_b,
    partition_key: :some_bool,
    values: false

  create_list_partition :bigint_custom_id_int_lists, primary_key: :some_id, partition_key: :some_int do |t|
    t.integer :some_int, null: false
  end

  create_list_partition_of :bigint_custom_id_int_lists,
    name: :bigint_custom_id_int_lists_a,
    primary_key: :some_id,
    partition_key: :some_int,
    values: [1, 2]

  create_list_partition_of :bigint_custom_id_int_lists,
    name: :bigint_custom_id_int_lists_b,
    primary_key: :some_id,
    partition_key: :some_int,
    values: [3, 4]

  create_list_partition :uuid_string_lists, id: :uuid, partition_key: :some_string do |t|
    t.text :some_string, null: false
  end

  create_list_partition_of :uuid_string_lists,
    name: :uuid_string_lists_a,
    partiton_key: :some_string,
    values: ["a", "b"]

  create_list_partition_of :uuid_string_lists,
    name: :uuid_string_lists_b,
    partiton_key: :some_string,
    values: ["c", "d"]
end
