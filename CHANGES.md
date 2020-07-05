## 1.4.0 - Postgres 11+ feature support and enhancements
#### Full Postgres 11 feature support has been added with complete backward compatibility
* When starting a fresh project with Postgres 11 or higher, you can disable template tables and enable primary key constraints on partitioned tables:
    * `config.create_template_tables` now governs whether template tables are created by default (defaults true).
    * `config.create_with_primary_key` passed down primary key options to CREATE TABLE, including support for composite primary keys
* `create_hash_partition`, `create_hash_partition_of`, and `attach_hash_partition` methods provide support for Hash partitions
* `create_default_partition_of` and `attach_default_partition` allows adding of default partitions to range and list partitioned tables
#### Full support for Subpartitioning
* `create_x_partition_of` methods now support `partition_type` and `partition_key`, which may be supplied to create
  a partitioned child table.
    * Use `create_x_partition_of` with the child table name to add a partition to your subpartition
    * Template tables are supported in that nested subpartitions will inherit from the top-level ancestor's template table, if found
* The `partitions` command now accepts an `include_subpartitions:` option which defaults to false for backward compatibility
    * Use `config.include_subpartitions_in_partition_list = true` to override the default
#### `add_index_on_all_partitions`
* Use this new adapter method in migrations to add an index on all partitions and subpartitions automatically
* This method supports `algorithm: :concurrently` to perform uptime operations, so even when using Postgres 11+ it is needed to avoid table locks.
* If you have many partitions, use the optional `in_threads:` option to parallelize index creation via the `parallel` gem
#### Minor enhancements
* Added adapter methods `partitions_for_table_name`, `parent_for_table_name`, and `table_partitioned?` to assist automating
partition management, especially where subpartitions are involved
  