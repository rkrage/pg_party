# PgParty

[![Gem Version](https://badge.fury.io/rb/pg_party.svg)][rubygems]
[![Build Status](https://circleci.com/gh/rkrage/pg_party.svg?&style=shield)][circle]
[![Maintainability](https://api.codeclimate.com/v1/badges/c409453d2283dd440227/maintainability)][cc_maintainability]
[![Test Coverage](https://api.codeclimate.com/v1/badges/c409453d2283dd440227/test_coverage)][cc_coverage]

[rubygems]:           https://rubygems.org/gems/pg_party
[circle]:             https://circleci.com/gh/rkrage/pg_party/tree/master
[cc_maintainability]: https://codeclimate.com/github/rkrage/pg_party/maintainability
[cc_coverage]:        https://codeclimate.com/github/rkrage/pg_party/test_coverage

[ActiveRecord](http://guides.rubyonrails.org/active_record_basics.html) migrations and model helpers for creating and managing [PostgreSQL 10+ partitions](https://www.postgresql.org/docs/10/static/ddl-partitioning.html)!

## Features

- Migration methods for partition specific database operations
- Model methods for querying partitioned data, creating adhoc partitions, and retreiving partition metadata

## Limitations

- Partition tables are not represented correctly in `db/schema.rb` — please use the `:sql` schema format

## Future Work

- Automatic partition creation (via cron or some other means)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pg_party'
```

And then execute:

```
$ bundle
```

Or install it yourself as:

```
$ gem install pg_party
```

Note that the gemspec does not require `pg`, as some model methods _may_ work for other databases.
Migration methods will be unavailable unless `pg` is installed.

## Configuration

These values can be accessed and set via `PgParty.config` and `PgParty.configure`.

- `caching`
  - Whether to cache currently attached partitions and anonymous model classes
  - Default: `true`
- `caching_ttl`
  - Length of time (in seconds) that cache entries are considered valid
  - Default: `-1` (never expire cache entries)
- `schema_exclude_partitions`
  - Whether to exclude child partitions in `rake db:structure:dump`
  - Default: `true`

Note that caching is done in-memory for each process of an application. Attaching / detaching partitions _will_ clear the cache, but only for the process that initiated the request. For multi-process web servers, it is recommended to use a TTL or disable caching entirely.

### Example

```ruby
# in a Rails initializer
PgParty.configure do |c|
  c.caching_ttl = 60
  c.schema_exclude_partitions = false
end
```

## Usage

### Migrations

#### Methods

These methods are available in migrations as well as `ActiveRecord::Base#connection` objects.

- `create_range_partition`
  - Create partitioned table using the _range_ partitioning method
  - Required args: `table_name`, `partitition_key:`
- `create_list_partition`
  - Create partitioned table using the _list_ partitioning method
  - Required args: `table_name`, `partition_key:`
- `create_range_partition_of`
  - Create partition in _range_ partitioned table with partition key between _range_ of values
  - Required args: `table_name`, `start_range:`, `end_range:`
- `create_list_partition_of`
  - Create partition in _list_ partitioned table with partition key in _list_ of values
  - Required args: `table_name`, `values:`
- `attach_range_partition`
  - Attach existing table to _range_ partitioned table with partition key between _range_ of values
  - Required args: `parent_table_name`, `child_table_name`, `start_range:`, `end_range:`
- `attach_list_partition`
  - Attach existing table to _list_ partitioned table with partition key in _list_ of values
  - Required args: `parent_table_name`, `child_table_name`, `values:`
- `detach_partition`
  - Detach partition from both _range and list_ partitioned tables
  - Required args: `parent_table_name`, `child_table_name`
- `create_table_like`
  - Clone _any_ existing table
  - Required args: `table_name`, `new_table_name`

#### Examples

Create _range_ partitioned table on `created_at::date` with two partitions:

```ruby
class CreateSomeRangeRecord < ActiveRecord::Migration[5.1]
  def up
    # proc is used for partition keys containing expressions
    create_range_partition :some_range_records, partition_key: ->{ "(created_at::date)" } do |t|
      t.text :some_value
      t.timestamps
    end

    # optional name argument is used to specify child table name
    create_range_partition_of \
      :some_range_records,
      name: :some_range_records_a,
      start_range: "2019-06-07",
      end_range: "2019-06-08"

    # optional name argument is used to specify child table name
     create_range_partition_of \
       :some_range_records,
       name: :some_range_records_b,
       start_range: "2019-06-08",
       end_range: "2019-06-09"
  end

  def down
    drop_table :some_range_records
    drop_table :some_range_records_template
  end
end
```

Create _list_ partitioned table on `id` with two partitions:

```ruby
class CreateSomeListRecord < ActiveRecord::Migration[5.1]
  def up
    # symbol is used for partition keys referring to individual columns
    create_list_partition :some_list_records, partition_key: :id do |t|
      t.text :some_value
      t.timestamps
    end

    # without name argument, child partition created as "some_list_records_<hash>"
    create_list_partition_of \
      :some_list_records,
      values: 1..100

    # without name argument, child partition created as "some_list_records_<hash>"
     create_list_partition_of \
       :some_list_records,
       values: 101..200
  end
end
```

Unfortunately, PostgreSQL 10 doesn't support indexes on partitioned tables.
However, individual _partitions_ can have indexes.
To avoid explicit index creation for _every_ new partition, we've introduced the idea of template tables.
For every call to `create_list_partition` and `create_range_partition`, a clone `<table_name>_template` is created.
Indexes, constraints, etc. created on the template table will propagate to new partitions in calls to `create_list_partition_of` and `create_range_partition_of`:

```ruby
class CreateSomeListRecord < ActiveRecord::Migration[5.1]
  def up
    # template table creation is enabled by default - use "template: false" to opt-out
    create_list_partition :some_list_records, partition_key: :id do |t|
      t.integer :some_foreign_id
      t.text :some_value
      t.timestamps
    end

    # create index on the template table
    add_index :some_list_records_template, :some_foreign_id

    # create partition with an index on "some_foreign_id"
    create_list_partition_of \
      :some_list_records,
      values: 1..100

    # create partition with an index on "some_foreign_id"
    create_list_partition_of \
      :some_list_records,
      values: 101..200
  end
end
```

Attach an existing table to a _range_ partitioned table:

```ruby
class AttachRangePartition < ActiveRecord::Migration[5.1]
  def up
    attach_range_partition \
      :some_range_records,
      :some_existing_table,
      start_range: "2019-06-09",
      end_range: "2019-06-10"
  end
end
```

Attach an existing table to a _list_ partitioned table:

```ruby
class AttachListPartition < ActiveRecord::Migration[5.1]
  def up
    attach_list_partition \
      :some_list_records,
      :some_existing_table,
      values: 200..300
  end
end
```

Detach a partition from any partitioned table:

```ruby
class DetachPartition < ActiveRecord::Migration[5.1]
  def up
    detach_partition :parent_table, :child_table
  end
end
```

For more examples, take a look at the Combustion schema definition and integration specs:

- https://github.com/rkrage/pg_party/blob/master/spec/dummy/db/schema.rb
- https://github.com/rkrage/pg_party/blob/master/spec/integration/migration_spec.rb

### Models

#### Methods

Class methods available to _all_ ActiveRecord models:

- `partitioned?`
  - Check if a model is backed by either a _list or range_ partitioned table
  - No arguments
- `range_partition_by`
  - Configure a model backed by a _range_ partitioned table
  - Required arg: `key` (partition key column) or block returning partition key expression
- `list_partition_by`
  - Configure a model backed by a _list_ partitioned table
  - Required arg: `key` (partition key column) or block returning partition key expression

Class methods available to both _range and list_ partitioned models:

- `partitions`
  - Retrieve a list of currently attached partitions
  - No arguments
- `in_partition`
  - Retrieve an ActiveRecord model scoped to an individual partition
  - Required arg: `child_table_name`
- `partition_key_eq`
  - Query for records where partition key matches a value
  - Required arg: `value`

Class methods available to _range_ partitioned models:

- `create_partition`
  - Dynamically create new partition with partition key in _range_ of values
  - Required args: `start_range:`, `end_range:`
- `partition_key_in`
  - Query for records where partition key in _range_ of values
  - Required args: `start_range`, `end_range`

Class methods available to _list_ partitioned models:

- `create_partition`
  - Dynamically create new partition with partition key in _list_ of values
  - Required arg: `values:`
- `partition_key_in`
  - Query for records where partition key in _list_ of values
  - Required arg: list of `values`

#### Examples

Configure model backed by a _range_ partitioned table to get access to the methods described above:

```ruby
class SomeRangeRecord < ApplicationRecord
  # block is used for partition keys containing expressions
  range_partition_by { "(created_at::date)" }
end
 ```

Configure model backed by a _list_ partitioned table to get access to the methods described above:

```ruby
class SomeListRecord < ApplicationRecord
  # symbol is used for partition keys referring to individual columns
  list_partition_by :id
end
```

Dynamically create new partition from _range_ partitioned model:

```ruby
# additional options include: "name:" and "primary_key:"
SomeRangeRecord.create_partition(start_range: "2019-06-09", end_range: "2019-06-10")
```

Dynamically create new partition from _list_ partitioned model:

```ruby
# additional options include: "name:" and "primary_key:"
SomeListRecord.create_partition(values: 200..300)
```

For _range_ partitioned model, query for records where partition key in _range_ of values:

```ruby
SomeRangeRecord.partition_key_in("2019-06-08", "2019-06-10")
```

For _list_ partitioned model, query for records where partition key in _list_ of values:

```ruby
SomeListRecord.partition_key_in(1, 2, 3, 4)
```

For both _range and list_ partitioned models, query for records matching partition key:

```ruby
SomeRangeRecord.partition_key_eq(Date.current)

SomeListRecord.partition_key_eq(100)
```

For both _range and list_ partitioned models, retrieve currently attached partitions:

```ruby
SomeRangeRecord.partitions

SomeListRecord.partitions
```

For both _range and list_ partitioned models, retrieve ActiveRecord model scoped to individual partition:

```ruby
SomeRangeRecord.in_partition(:some_range_records_partition_name)

SomeListRecord.in_partition(:some_list_records_partition_name)
```

To create _range_ partitions by month for previous, current and next months it's possible to use this example. To automate creation of partitions, run `EventLogArchive.maintenance` every day with cron:

```ruby
class Log < ApplicationRecord
  range_partition_by { '(created_at::date)' }

  def self.maintenance
    partitions = [Date.today.prev_month, Date.today, Date.today.next_month]

    partitions.each do |day|
      name = Log.partition_name_for(day)
      next if ActiveRecord::Base.connection.table_exists?(name)
      Log.create_partition(
        name: name,
        start_range: day.beginning_of_month,
        end_range: day.end_of_month
      )
    end
  end

  def self.partition_name_for(day)
    "logs_y#{day.year}_m#{day.month}"
  end
end
```

For more examples, take a look at the model integration specs:

- https://github.com/rkrage/pg_party/tree/documentation/spec/integration/model

## Development

The development / test environment relies heavily on [Docker](https://docs.docker.com).

Start the containers in the background:

```
$ docker-compose up -d
```

Install dependencies:

```
$ bin/de bundle
$ bin/de appraisal
```

Run the tests:

```
$ bin/de appraisal rake
```

Open a Pry console to play around with the sample Rails app:

```
$ bin/de console
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rkrage/pg_party. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PgParty project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/rkrage/pg_party/blob/master/CODE_OF_CONDUCT.md).
