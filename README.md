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

## Compatibility

This gem is tested against:

- Rails: 6.1, 7.0, 7.1, 7.2, 8.0
- Ruby: 3.0, latest (currently 3.3 at the time of this commit)
- PostgreSQL: 11, 12, 13, 14, 15, 16, 17

## Future Work

I plan to separate out the model functionality into a new gem and port the migration functionality into [pg\_ha\_migrations](https://github.com/braintree/pg_ha_migrations) (some of which has already been done).
I will continue to maintain this gem (bugfixes / support for new versions of Rails) until that work is complete.

I originally planned to add a feature for automatic partition creation, but I think that functionality would be better served by [pg\_partman](https://github.com/pgpartman/pg_partman).

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
- `create_template_tables`
  - Whether to create template tables by default. Use the `template:` option when creating partitioned tables to override this default.
  - Default: `true`
- `create_with_primary_key`
  - Whether to add primary key constraints to partitioned (parent) tables by default.
    * This behavior is disabled by default as this configuration usually requires composite primary keys to be specified
      and ActiveRecord does not natively support composite primary keys. There are workarounds such as the
      [composite_primary_keys gem](https://github.com/composite-primary-keys/composite_primary_keys).
    * This is not supported for Postgres 10 (requires Postgres 11+)
    * Primary key constraints must include all partition keys, for example: `primary_key: [:id, :created_at], partition_key: :created_at`
    * Partition keys cannot use expressions
    * Can be overridden via the `create_with_primary_key:` option when creating partitioned tables
  - Default: `false`
- `include_subpartitions_in_partition_list`
  - Whether to include nested subpartitions in the result of `YourModelClass.partiton_list` mby default.
    You can always pass the `include_subpartitions:` option to override this.
  - Default: `false` (for backward compatibility)

Note that caching is done in-memory for each process of an application. Attaching / detaching partitions _will_ clear the cache, but only for the process that initiated the request. For multi-process web servers, it is recommended to use a TTL or disable caching entirely.

### Example

```ruby
# in a Rails initializer
PgParty.configure do |c|
  c.caching_ttl = 60
  c.schema_exclude_partitions = false
  c.include_subpartitions_in_partition_list = true
  # Postgres 11+ users starting fresh may consider the below options to rely on Postgres' native features instead of
  # this gem's template tables feature.
  c.create_template_tables = false
  c.create_with_primary_key = true
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
- `create_hash_partition` (Postgres 11+)
  - Create partitioned table using the _hash_ partitioning method
  - Required args: `table_name`, `partition_key:`
- `create_range_partition_of`
  - Create partition in _range_ partitioned table with partition key between _range_ of values
  - Required args: `table_name`, `start_range:`, `end_range:`
  - Create a subpartition by specifying a `partition_type:` of `:range`, `:list`, or `:hash` and a `partition_key:`
- `create_list_partition_of`
  - Create partition in _list_ partitioned table with partition key in _list_ of values
  - Required args: `table_name`, `values:`
  - Create a subpartition by specifying a `partition_type:` of `:range`, `:list`, or `:hash` and a `partition_key:`
- `create_hash_partition_of` (Postgres 11+)
  - Create partition in _hash_ partitioned table for partition keys with hashed values having a specific remainder
  - Required args: `table_name`, `modulus:`, `remainder`
  - Create a subpartition by specifying a `partition_type:` of `:range`, `:list`, or `:hash` and a `partition_key:`
  - Note that all partitions in a _hash_ partitioned table should have the same modulus. See [Examples](#examples) for more info.
- `create_default_partition_of` (Postgres 11+)
  - Create a default partition for values not falling in the range or list constraints of any other partitions
  - Required args: `table_name`
- `attach_range_partition`
  - Attach existing table to _range_ partitioned table with partition key between _range_ of values
  - Required args: `parent_table_name`, `child_table_name`, `start_range:`, `end_range:`
- `attach_list_partition`
  - Attach existing table to _list_ partitioned table with partition key in _list_ of values
  - Required args: `parent_table_name`, `child_table_name`, `values:`
- `attach_hash_partition` (Postgres 11+)
  - Attach existing table to _hash_ partitioned table with partition key hashed values having a specific remainder
  - Required args: `parent_table_name`, `child_table_name`, `modulus:`, `remainder`
- `attach_default_partition` (Postgres 11+)
  - Attach existing table as the _default_ partition
  - Required args: `parent_table_name`, `child_table_name`
- `detach_partition`
  - Detach partition from both _range and list_ partitioned tables
  - Required args: `parent_table_name`, `child_table_name`
- `create_table_like`
  - Clone _any_ existing table
  - Required args: `table_name`, `new_table_name`
- `partitions_for_table_name`
  - List all attached partitions for a given table
  - Required args: `table_name`, `include_subpartitions:` (true or false)
- `parent_for_table_name`
  - Fetch the parent table for a partition
  - Required args: `table_name`
  - Pass optional `traverse: true` to return the top-level table in the hierarchy (for subpartitions)
  - Returns `nil` if the table is not a partition / has no parent
- `table_partitioned?`
  - Returns true if the table is partitioned (false for non-partitioned tables and partitions themselves)
  - Required args: `table_name`
- `add_index_on_all_partitions`
  - Recursively add an index to all partitions and subpartitions of `table_name` using Postgres's ADD INDEX CONCURRENTLY
    algorithm which adds the index in a non-blocking manner.
  - Required args: `table_name`, `column_name` (all `add_index` arguments are supported)
  - Use the `in_threads:` option to add indexes in parallel threads when there are many partitions. A value of 2 to 4
    may be reasonable for tables with many large partitions and hosts with 4+ CPUs/cores.
  - Use `disable_ddl_transaction!` in your migration to disable transactions when using this command with `in_threads:`
    or `algorithm: :concurrently`.

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

    # default partition support is available in Postgres 11 or higher
     create_default_partition_of \
       :some_list_records
  end
end
```

Create _hash_ partitioned table on `account_id` with two partitions (Postgres 11+ required):
  * A hash partition can be used to spread keys evenly(ish) across partitions
  * `modulus:` should always equal the total number of partitions planned for the table
  * `remainder:` is an integer which should be in the range of 0 to modulus-1

```ruby
class CreateSomeHashRecord < ActiveRecord::Migration[5.1]
  def up
    # symbol is used for partition keys referring to individual columns
    # create_with_primary_key: true, template: false on Postgres 11 will rely on PostgreSQL's native partition schema
    # management vs this gem's template tables
    # Note composite primary keys will require a workaround in ActiveRecord, such as through the use of the composite_primary_keys gem
    create_hash_partition :some_hash_records, partition_key: :account_id, primary_key: [:id, :account_id],
    create_with_primary_key: true, template: false do |t|
      t.bigserial :id, null: false
      t.bigint :account_id, null: false
      t.text :some_value
      t.timestamps
    end

    # without name argument, child partition created as "some_list_records_<hash>"
    create_hash_partition_of \
      :some_hash_records,
      modulus: 2,
      remainder: 0

    # without name argument, child partition created as "some_list_records_<hash>"
    create_hash_partition_of \
      :some_hash_records,
      modulus: 2,
      remainder: 1
  end
end
```

Advanced example with subpartitioning: Create _list_ partitioned table on `account_id` subpartitioned by _range_ on `created_at`
with default partitions. This example is for a table with no primary key... perhaps for some analytics use case.
* Default partitions are only supported in Postgres 11+

```ruby
class CreateSomeListSubpartitionedRecord < ActiveRecord::Migration[5.1]
  def up
    create_list_partition :some_list_subpartitioned_records, partition_key: :account_id, id: false,
      template: false do |t|
      t.bigint :account_id, null: false
      t.text :some_value
      t.created_at
    end

    create_default_partition_of \
      :some_list_subpartitioned_records,
      name: :some_list_subpartitioned_records_default,
      partition_type: :range,
      partition_key: :created_at

    create_range_partition_of \
      :some_list_subpartitioned_records_default,
      name: :some_list_subpartitioned_records_default_2019,
      start_range: '2019-01-01',
      end_range: '2019-12-31T23:59:59'

    create_default_partition_of \
      :some_list_subpartitioned_records_default

    create_list_partition_of \
      :some_list_subpartitioned_records,
      name: :some_list_subpartitioned_records_1,
      values: 1..100,
      partition_type: :range,
      partition_key: :created_at

    create_range_partition_of \
      :some_list_subpartitioned_records_1,
      name: :some_list_subpartitioned_records_1_2019,
      start_range: '2019-01-01',
      end_range: '2019-12-31T23:59:59'

    create_default_partition_of
      :some_list_subpartitioned_records_1

     create_list_partition_of \
       :some_list_subpartitioned_records,
       name: :some_list_subpartitioned_records_2,
       values: 101..200,
       partition_type: :range,
       partition_key: :created_at

    create_range_partition_of \
      :some_list_subpartitioned_records_2,
      name: :some_list_subpartitioned_records_2_2019,
      start_range: '2019-01-01',
      end_range: '2019-12-31T23:59:59'

    create_default_partition_of \
      :some_list_subpartitioned_records_2
  end
end
```

#### Template Tables
Unfortunately, PostgreSQL 10 doesn't support indexes on partitioned tables.
However, individual _partitions_ can have indexes.
To avoid explicit index creation for _every_ new partition, we've introduced the idea of template tables.
For every call to `create_list_partition` and `create_range_partition`, a clone `<table_name>_template` is created.
Indexes, constraints, etc. created on the template table will propagate to new partitions in calls to `create_list_partition_of` and `create_range_partition_of`:
* Subpartitions will correctly clone from template tables if a template table exists for the top-level ancestor
* When using Postgres 11 or higher, you may wish to disable template tables and use the native features instead, see [Configuration](#configuration)\
  but this may result in you using composite primary keys, which is not natively supported by ActiveRecord.

```ruby
class CreateSomeListRecord < ActiveRecord::Migration[5.1]
  def up
    # template table creation is enabled by default - use "template: false" or the config option to opt-out
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

#### Attaching Existing Tables as Partitions

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

Attach an existing table to a _hash_ partitioned table:

```ruby
class AttachHashPartition < ActiveRecord::Migration[5.1]
  def up
    attach_hash_partition \
      :some_hash_records,
      :some_existing_table,
      modulus: 2,
      remainder: 1
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

#### Safely cascading `add_index` commands
Postgres 11+ will automatically cascade CREATE INDEX operations to partitions and subpartitions, however
CREATE INDEX CONCURRENTLY is not supported, meaning table locks will be taken on each table while the new index is built.
Postgres 10 provides no way to cascade index creation natively.
* The `add_index_on_all_partitions` method solves for these limitations by recursively creating the specified
  index on all partitions and subpartitions. Index names on individual partitions will include a hash suffix to avoid conflicts.
* On Postgres 11+, the created indices are correctly attached to an index on the parent table
* On Postgres 10, if you are using [Template Tables](#template-tables-for-postgres-10), you will want to add the index to the template table separately.
* This command can also be used on subpartitions to cascade targeted indices starting at one level of the table hierarchy

```ruby
class AddSomeValueIndexToSomeListRecord < ActiveRecord::Migration[5.1]
  # add_index_on_all_partitions with in_threads option may not be used within a transaction
  # (also, algorithm: :concurrently cannot be used within a transaction)
  disable_ddl_transaction!

  def up
    add_index :some_records_template, :some_value # Only if using Postgres 10 with template tables

    # Pass the `in_threads:` option to create indices in parallel across multiple Postgres connections
    add_index_on_all_partitions :some_records, :some_value, algorithm: :concurrently, in_threads: 4
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
- `hash_partition_by`
  - Configure a model backed by a _hash_ partitioned table
  - Required arg: `key` (partition key column) or block returning partition key expression

Class methods available to both _range and list_ partitioned models:

- `partitions`
  - Retrieve a list of currently attached partitions
  - Optional `include_subpartitions:` argument to include all subpartitions in the returned list
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


Class methods available to _hash_ partitioned models:

- `create_partition`
  - Dynamically create new partition with hashed partition key divided by _modulus_ equals _remainder_
  - Required arg: `modulus:`, `remainder:`
- `partition_key_in`
  - Query for records where partition key in _list_ of values (method operates the same as for _list_ partitions above)
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

Configure model backed by a _hash_ partitioned table to get access to the methods described above:

```ruby
class SomeHashRecord < ApplicationRecord
  # symbol is used for partition keys referring to individual columns
  hash_partition_by :id
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

Dynamically create new partition from _hash_ partitioned model:

```ruby
# additional options include: "name:" and "primary_key:"
SomeHashRecord.create_partition(modulus: 2, remainder: 1)
```

For _range_ partitioned model, query for records where partition key in _range_ of values:

```ruby
SomeRangeRecord.partition_key_in("2019-06-08", "2019-06-10")
```

For _list_ and _hash_ partitioned models, query for records where partition key in _list_ of values:

```ruby
SomeListRecord.partition_key_in(1, 2, 3, 4)
```

For all partitioned models, query for records matching partition key:

```ruby
SomeRangeRecord.partition_key_eq(Date.current)

SomeListRecord.partition_key_eq(100)
```

For all partitioned models, retrieve currently attached partitions:

```ruby
SomeRangeRecord.partitions

SomeListRecord.partitions(include_subpartitions: true) # Include nested subpartitions
```

For both all partitioned models, retrieve ActiveRecord model scoped to individual partition:

```ruby
SomeRangeRecord.in_partition(:some_range_records_partition_name)

SomeListRecord.in_partition(:some_list_records_partition_name)
```

To create _range_ partitions by month for previous, current and next months it's possible to use this example. To automate creation of partitions, run `Log.maintenance` every day with cron:

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
        end_range: day.next_month.beginning_of_month
      )
    end
  end

  def self.partition_name_for(day)
    "logs_y#{day.year}_m#{day.month}"
  end
end
```

For more examples, take a look at the model integration specs:

- https://github.com/rkrage/pg_party/tree/master/spec/integration/model

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
