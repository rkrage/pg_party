## 1.4.0 - Postgres 11+ feature support and enhancements
Postgres 11 feature support has been added with full backward compatibility.
* `config.create_template_tables` now governs whether template tables are created by default (defaults true). When starting
  fresh with Postgres 11+ you may want to disable template tables and enable `config.create_with_primary_key` to use these native features.
* Set `config.create_with_primary_key` to true to create primary keys on partitioned tables in Postgres 11+
  * Composite primary keys are now allowed when this setting is enabled
* `create_hash_partition`, `create_hash_partition_of`, and `attach_hash_partition` methods provide support for Hash partitions in Postgres 11+
* `create_default_partition_of` and `attach_default_partition` allows adding of default partitions to range and list partitioned tables in Postgres 11+
* Subpartition support! `create_x_partition_of` methods now support `partition_type` and `partition_key`, which may be supplied to create
  a partitioned child table. Use `create_x_partition_of` to add a partition to your subpartition.
  * Template tables are only created for top-level tables but will be correctly used by deeply nested subpartitions
* The `partitions` command now accepts an `include_subpartitions:` option (default based on config 
  `include_subpartitions_in_partition_list`) which will cascade to return all
subpartitions in the hierarchy
* Added adapter methods `partitions_for_table_name` and `parent_for_table_name` to assist automating partition management
* Added adapter method `add_index_on_all_partitions` to automatically cascade index creation to all partitions and
subpartitions, providing support for `algorithm: :concurrently` (which Postgres 11 does not on partitioned tables)
  * This feature uses the `parallel` gem to allow parallel index creation via the `in_threads:` option