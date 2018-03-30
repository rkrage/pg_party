# PgParty

[![Gem Version](https://badge.fury.io/rb/pg_party.svg)][rubygems]
[![Build Status](https://circleci.com/gh/rkrage/pg_party.svg?&style=shield)][circle]
[![Dependency Status](https://gemnasium.com/badges/github.com/rkrage/pg_party.svg)][gemnasium]
[![Maintainability](https://api.codeclimate.com/v1/badges/c409453d2283dd440227/maintainability)][cc_maintainability]
[![Test Coverage](https://api.codeclimate.com/v1/badges/c409453d2283dd440227/test_coverage)][cc_coverage]

[rubygems]:           https://rubygems.org/gems/pg_party
[circle]:             https://circleci.com/gh/rkrage/pg_party/tree/master
[gemnasium]:          https://gemnasium.com/github.com/rkrage/pg_party
[cc_maintainability]: https://codeclimate.com/github/rkrage/pg_party/maintainability
[cc_coverage]:        https://codeclimate.com/github/rkrage/pg_party/test_coverage

[ActiveRecord](http://guides.rubyonrails.org/active_record_basics.html) migrations and model helpers for creating and managing [PostgreSQL 10 partitions](https://www.postgresql.org/docs/10/static/ddl-partitioning.html)!

Features:
  - Migration methods for partition specific database operations
  - Model methods for querying partitioned data
  - Model methods for creating adhoc partitions

Limitations:
  - Partition tables are not represented correctly in `db/schema.rb` — please use the `:sql` schema format
  - Only single column partition keys supported (e.g., `column`, `column::cast`)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pg_party'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pg_party

## Usage

Full API documentation is in progress.

In the meantime, take a look at the [Combustion](https://github.com/pat/combustion) schema definition and integration specs:
  - https://github.com/rkrage/pg_party/blob/master/spec/internal/db/schema.rb
  - https://github.com/rkrage/pg_party/tree/master/spec/integration

### Migration Examples

Create range partition on `created_at::date` with two child partitions:

```ruby
class CreateSomeRangeRecord < ActiveRecord::Migration[5.1]
  def up
    current_date = Date.current

    create_range_partition :some_range_records, partition_key: "created_at::date" do |t|
      t.text :some_value
      t.timestamps
    end

    create_range_partition_of \
      :some_range_records,
      partition_key: "created_at::date",
      start_range: current_date,
      end_range: current_date + 1.day

     create_range_partition_of \
       :some_range_records,
       partition_key: "created_at::date",
       start_range: current_date + 1.day,
       end_range: current_date + 2.days
  end
end
```

Create list partition on `id` with two child partitions:

```ruby
class CreateSomeListRecord < ActiveRecord::Migration[5.1]
  def up
    create_list_partition :some_list_records, partition_key: :id do |t|
      t.text :some_value
      t.timestamps
    end

    create_list_partition_of \
      :some_list_records,
      partition_key: :id,
      values: (1..100).to_a

     create_list_partition_of \
       :some_list_records,
       partition_key: :id,
       values: (101..200).to_a
  end
end
```

If a partitioned table requires an index on a column other than the partition key, an explicit `add_index` operation is required for each child partition:

```ruby
class CreateSomeListRecord < ActiveRecord::Migration[5.1]
  def up
    create_list_partition :some_list_records, partition_key: :id do |t|
      t.integer :some_foreign_id
      t.text :some_value
      t.timestamps
    end

    # Partition with dynamically generated table name returned
    partition_table = create_list_partition_of \
      :some_list_records,
      partition_key: :id,
      values: (1..100).to_a

    # Partition with user-specified table name
    create_list_partition_of \
      :some_list_records,
      name: :some_list_records_101_200,
      partition_key: :id,
      values: (101..200).to_a

    # indexes for newly created partition tables
    add_index partition_table, :some_foreign_id
    add_index :some_list_records_101_200, :some_foreign_id
  end
end
```

If a partitioned table requires an index on a column other than the partition key, an explicit add_index operation is required for each child partition:

```ruby
class CreateSomeListRecord < ActiveRecord::Migration[5.1]
  def up
    create_list_partition :some_list_records, partition_key: :id do |t|
      t.integer :some_foreign_id
      t.text :some_value
      t.timestamps
    end

    # Partition with dynamically generated table name returned
    partition_table = create_list_partition_of \
      :some_list_records,
      partition_key: :id,
      values: (1..100).to_a

    # Partition with user-specified table name
    create_list_partition_of \
      :some_list_records,
      name: 'some_list_records_101_200',
      partition_key: :id,
      values: (101..200).to_a

    # indexes for newly created partition tables
    add_index partition_table, :some_foreign_id
    add_index 'some_list_records_101_200', :some_foreign_id
  end
end
```

Attach an existing table to a range partition:

```ruby
class AttachRangePartition < ActiveRecord::Migration[5.1]
  def up
    current_date = Date.current

    attach_range_partition \
      :some_range_records,
      :some_existing_table,
      start_range: current_date,
      end_range: current_date + 1.day
  end
end
```

Attach an existing table to a list partition:

```ruby
class AttachListPartition < ActiveRecord::Migration[5.1]
  def up
    attach_list_partition \
      :some_list_records,
      :some_existing_table,
      values: (201..300).to_a
  end
end
```

Detach a child table from any partition:

```ruby
class DetachPartition < ActiveRecord::Migration[5.1]
  def up
    detach_partition :parent_table, :child_table
  end
end
```

### Model Examples

Define model that is backed by a range partition:

```ruby
class SomeRangeRecord < ApplicationRecord
  range_partition_by "created_at::date"
end
 ```

Define model that is backed by a list partition:

```ruby
class SomeListRecord < ApplicationRecord
  list_partition_by :id
end
```

Create child partition from range partition model:

```ruby
current_date = Date.current

SomeRangeRecord.create_partition(start_range: current_date + 1.day, end_range: current_date + 2.days)
```

Create child partition from list partition model:

```ruby
SomeListRecord.create_partition(values: (200..300).to_a)
```

Query for records within partition range:

```ruby
SomeRangeRecord.partition_key_in("2017-01-01".to_date, "2017-02-01".to_date)
```

Query for records in partition list:

```ruby
SomeListRecord.partition_key_in(1, 2, 3, 4)
```

Query for records matching partition key:

```ruby
SomeRangeRecord.partition_key_eq(Date.current)

SomeListRecord.partition_key_eq(100)
```

List currently attached partitions:

```ruby
SomeRangeRecord.partitions

SomeListRecord.partitions
```

Retrieve ActiveRecord model class scoped to a child partition:

```ruby
SomeRangeRecord.in_partition(:some_range_records_partition_name)

SomeListRecord.in_partition(:some_list_records_partition_name)
```

## Development

The development / test environment relies heavily on [Docker](https://docs.docker.com).

Start the containers in the background:

    $ docker-compose up -d

Install dependencies:

    $ bin/de bundle
    $ bin/de appraisal

Run the tests:

    $ bin/de appraisal rake

Open a Pry console to play around with the sample Rails app:

    $ bin/de console

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rkrage/pg_party. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PgParty project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/rkrage/pg_party/blob/master/CODE_OF_CONDUCT.md).
