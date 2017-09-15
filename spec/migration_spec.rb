require "spec_helper"

RSpec.describe ActiveRecord::ConnectionAdapters::AbstractAdapter do
  let(:connection) { ActiveRecord::Base.connection }
  let(:custom_adapter_instance) { custom_adapter_class.new }
  let(:custom_adapter_class) do
    Class.new(ActiveRecord::ConnectionAdapters::AbstractAdapter) do
      def initialize
        # so we can create an adapter instance without connection config
      end
    end
  end

  describe "#create_range_partition" do
    let(:table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:keyword_args) do
      {
        partition_key: :id
      }
    end

    let(:block) { Proc.new { } }

    subject(:create_range_partition) { connection.create_range_partition(table_name, keyword_args, &block) }

    context "with non-postgres adapter" do
      before { allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance) }

      it "raises not implemented error" do
        expect { create_range_partition }.to raise_error(NotImplementedError, "#create_range_partition is not implemented")
      end
    end

    context "with postgres adapter" do
      after { connection.execute("DROP TABLE IF EXISTS #{table_name} CASCADE") }

      subject(:sql_dump) do
        create_range_partition
        PgDumpHelper.dump_table_structure(table_name)
      end

      context "with column as partition key" do
        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                id bigint NOT NULL
            ) PARTITION BY RANGE (id);
          SQL
        end

        let(:create_sequence_statement) { "CREATE SEQUENCE #{table_name}_id_seq" }

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates create sequence statement" do
          expect(sql_dump).to include(create_sequence_statement)
        end
      end

      context "with uuid primary key" do
        let(:uuid_function) do
          if Rails.gem_version >= Gem::Version.new("5.1")
            "gen_random_uuid()"
          else
            "uuid_generate_v4()"
          end
        end

        let(:keyword_args) do
          {
            id: :uuid,
            partition_key: :some_identifier
          }
        end

        let(:block) do
          ->(t) do
            t.bigint :some_identifier, null: false
          end
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                id uuid DEFAULT #{uuid_function} NOT NULL,
                some_identifier bigint NOT NULL
            ) PARTITION BY RANGE (some_identifier);
          SQL
        end

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "does not generate sequence statement" do
          expect(sql_dump).to_not include("CREATE SEQUENCE")
        end
      end

      context "without primary key" do
        let(:keyword_args) do
          {
            id: false,
            partition_key: :some_identifier
          }
        end

        let(:block) do
          ->(t) do
            t.bigint :some_identifier, null: false
          end
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                some_identifier bigint NOT NULL
            ) PARTITION BY RANGE (some_identifier);
          SQL
        end

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "does not generate sequence statement" do
          expect(sql_dump).to_not include("CREATE SEQUENCE")
        end
      end

      context "with custom primary key name" do
        let(:keyword_args) do
          {
            primary_key: :custom_id,
            partition_key: :custom_id
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                custom_id bigint NOT NULL
            ) PARTITION BY RANGE (custom_id);
          SQL
        end

        let(:create_sequence_statement) { "CREATE SEQUENCE #{table_name}_custom_id_seq" }

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates create sequence statement" do
          expect(sql_dump).to include(create_sequence_statement)
        end
      end

      context "with casted column partition key" do
        let(:keyword_args) do
          {
            partition_key: "created_at::date"
          }
        end

        let(:block) do
          ->(t) do
            t.timestamps
          end
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                id bigint NOT NULL,
                created_at timestamp without time zone NOT NULL,
                updated_at timestamp without time zone NOT NULL
            ) PARTITION BY RANGE (((created_at)::date));
          SQL
        end

        let(:create_sequence_statement) { "CREATE SEQUENCE #{table_name}_id_seq" }

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates create sequence statement" do
          expect(sql_dump).to include(create_sequence_statement)
        end
      end
    end
  end

  describe "#create_list_partition" do
    let(:table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:keyword_args) do
      {
        partition_key: :id
      }
    end

    let(:block) { Proc.new { } }

    subject(:create_list_partition) { connection.create_list_partition(table_name, keyword_args, &block) }

    context "with non-postgres adapter" do
      before { allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance) }

      it "raises not implemented error" do
        expect { create_list_partition }.to raise_error(NotImplementedError, "#create_list_partition is not implemented")
      end
    end

    context "with postgres adapter" do
      after { connection.execute("DROP TABLE IF EXISTS #{table_name} CASCADE") }

      subject(:sql_dump) do
        create_list_partition
        PgDumpHelper.dump_table_structure(table_name)
      end

      context "identifier based partition" do
        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                id bigint NOT NULL
            ) PARTITION BY LIST (id);
          SQL
        end

        let(:create_sequence_statement) { "CREATE SEQUENCE #{table_name}_id_seq" }

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates create sequence statement" do
          expect(sql_dump).to include(create_sequence_statement)
        end
      end

      context "boolean based partition" do
        let(:keyword_args) do
          {
            partition_key: :active
          }
        end

        let(:block) do
          ->(t) do
            t.boolean :active, null: false, default: true
          end
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                id bigint NOT NULL,
                active boolean DEFAULT true NOT NULL
            ) PARTITION BY LIST (active);
          SQL
        end

        let(:create_sequence_statement) { "CREATE SEQUENCE #{table_name}_id_seq" }

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates create sequence statement" do
          expect(sql_dump).to include(create_sequence_statement)
        end
      end
    end
  end

  describe "#create_range_partition_of" do
    let(:parent_table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:child_table_name) { create_range_partition_of }
    let(:current_date) { Date.current }
    let(:start_range) { current_date }
    let(:end_range) { current_date + 1.month }
    let(:keyword_args) do
      {
        start_range: start_range,
        end_range: end_range
      }
    end

    subject(:create_range_partition_of) { connection.create_range_partition_of(parent_table_name, keyword_args) }

    context "with non-postgres adapter" do
      before { allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance) }

      it "raises not implemented error" do
        expect { create_range_partition_of }.to raise_error(NotImplementedError, "#create_range_partition_of is not implemented")
      end
    end

    context "with postgres adapter" do
      after { connection.execute("DROP TABLE IF EXISTS #{parent_table_name} CASCADE") }

      subject(:sql_dump) do
        create_range_partition_of
        PgDumpHelper.dump_table_structure(child_table_name)
      end

      context "with date range" do
        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
            FOR VALUES FROM ('#{start_range}') TO ('#{end_range}');
          SQL
        end

        let(:primary_key_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name}
            ADD CONSTRAINT #{child_table_name}_pkey PRIMARY KEY (id);
          SQL
        end

        let(:primary_key_default_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name} ALTER COLUMN id
            SET DEFAULT nextval('#{parent_table_name}_id_seq'::regclass);
          SQL
        end

        before do
          connection.create_range_partition(parent_table_name, partition_key: "created_at::date") do |t|
            t.timestamps
          end
        end

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates primary key statement" do
          expect(sql_dump).to include(primary_key_statement)
        end

        it "generates primary key default value statement" do
          expect(sql_dump).to include(primary_key_default_statement)
        end

        it "does not generate create index statement" do
          expect(sql_dump).to_not include("CREATE INDEX")
        end
      end

      context "with sequential id range" do
        let(:keyword_args) do
          {
            start_range: 1,
            end_range: 100
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
            FOR VALUES FROM ('1') TO ('100');
          SQL
        end

        let(:primary_key_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name}
            ADD CONSTRAINT #{child_table_name}_pkey PRIMARY KEY (id);
          SQL
        end

        let(:primary_key_default_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name} ALTER COLUMN id
            SET DEFAULT nextval('#{parent_table_name}_id_seq'::regclass);
          SQL
        end

        before { connection.create_range_partition(parent_table_name, partition_key: :id) }

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates primary key statement" do
          expect(sql_dump).to include(primary_key_statement)
        end

        it "generates primary key default value statement" do
          expect(sql_dump).to include(primary_key_default_statement)
        end

        it "does not generate create index statement" do
          expect(sql_dump).to_not include("CREATE INDEX")
        end
      end

      context "with custom primary key" do
        let(:keyword_args) do
          {
            primary_key: :custom_id,
            start_range: 1,
            end_range: 100
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
            FOR VALUES FROM ('1') TO ('100');
          SQL
        end

        let(:primary_key_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name}
            ADD CONSTRAINT #{child_table_name}_pkey PRIMARY KEY (custom_id);
          SQL
        end

        let(:primary_key_default_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name} ALTER COLUMN custom_id
            SET DEFAULT nextval('#{parent_table_name}_custom_id_seq'::regclass);
          SQL
        end

        before { connection.create_range_partition(parent_table_name, primary_key: :custom_id, partition_key: :custom_id) }

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates primary key statement" do
          expect(sql_dump).to include(primary_key_statement)
        end

        it "generates primary key default value statement" do
          expect(sql_dump).to include(primary_key_default_statement)
        end

        it "does not generate create index statement" do
          expect(sql_dump).to_not include("CREATE INDEX")
        end
      end

      context "without primary key" do
        let(:keyword_args) do
          {
            primary_key: false,
            start_range: 1,
            end_range: 100
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
            FOR VALUES FROM ('1') TO ('100');
          SQL
        end

        before do
          connection.create_range_partition(parent_table_name, id: false, partition_key: :custom_id) do |t|
            t.bigint :custom_id, null: false
          end
        end

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "does not generate primary key statement" do
          expect(sql_dump).to_not include("ADD CONSTRAINT")
        end

        it "does not generate primary key default value statement" do
          expect(sql_dump).to_not include("SET DEFAULT nextval")
        end

        it "does not generate create index statement" do
          expect(sql_dump).to_not include("CREATE INDEX")
        end
      end

      context "with partition key and index true" do
        let(:keyword_args) do
          {
            partition_key: "created_at::date",
            start_range: start_range,
            end_range: end_range
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
            FOR VALUES FROM ('#{start_range}') TO ('#{end_range}');
          SQL
        end

        let(:primary_key_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name}
            ADD CONSTRAINT #{child_table_name}_pkey PRIMARY KEY (id);
          SQL
        end

        let(:primary_key_default_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name} ALTER COLUMN id
            SET DEFAULT nextval('#{parent_table_name}_id_seq'::regclass);
          SQL
        end

        let(:index_statement) do
          <<-SQL.squish
            CREATE INDEX index_#{child_table_name}_on_created_at_date
            ON #{child_table_name}
            USING btree (((created_at)::date));
          SQL
        end

        before do
          connection.create_range_partition(parent_table_name, partition_key: "created_at::date") do |t|
            t.timestamps
          end
        end

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates primary key statement" do
          expect(sql_dump).to include(primary_key_statement)
        end

        it "generates primary key default value statement" do
          expect(sql_dump).to include(primary_key_default_statement)
        end

        it "generates create index statement" do
          expect(sql_dump).to include(index_statement)
        end
      end

      context "with partition key and index false" do
        let(:keyword_args) do
          {
            partition_key: "created_at::date",
            start_range: start_range,
            end_range: end_range,
            index: false
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
            FOR VALUES FROM ('#{start_range}') TO ('#{end_range}');
          SQL
        end

        let(:primary_key_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name}
            ADD CONSTRAINT #{child_table_name}_pkey PRIMARY KEY (id);
          SQL
        end

        let(:primary_key_default_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name} ALTER COLUMN id
            SET DEFAULT nextval('#{parent_table_name}_id_seq'::regclass);
          SQL
        end

        before do
          connection.create_range_partition(parent_table_name, partition_key: "created_at::date") do |t|
            t.timestamps
          end
        end

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates primary key statement" do
          expect(sql_dump).to include(primary_key_statement)
        end

        it "generates primary key default value statement" do
          expect(sql_dump).to include(primary_key_default_statement)
        end

        it "does not generate create index statement" do
          expect(sql_dump).to_not include("CREATE INDEX")
        end
      end

      context "with partition key same as primary key and index true" do
        let(:keyword_args) do
          {
            partition_key: :id,
            start_range: 1,
            end_range: 100
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
            FOR VALUES FROM ('1') TO ('100');
          SQL
        end

        let(:primary_key_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name}
            ADD CONSTRAINT #{child_table_name}_pkey PRIMARY KEY (id);
          SQL
        end

        let(:primary_key_default_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name} ALTER COLUMN id
            SET DEFAULT nextval('#{parent_table_name}_id_seq'::regclass);
          SQL
        end

        before { connection.create_range_partition(parent_table_name, partition_key: :id) }

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates primary key statement" do
          expect(sql_dump).to include(primary_key_statement)
        end

        it "generates primary key default value statement" do
          expect(sql_dump).to include(primary_key_default_statement)
        end

        it "does not generate create index statement" do
          expect(sql_dump).to_not include("CREATE INDEX")
        end
      end
    end
  end

  describe "#create_list_partition_of" do
    let(:parent_table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:child_table_name) { create_list_partition_of }
    let(:keyword_args) do
      {
        values: [1,2,3,4]
      }
    end

    subject(:create_list_partition_of) { connection.create_list_partition_of(parent_table_name, keyword_args) }

    context "with non-postgres adapter" do
      before { allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance) }

      it "raises not implemented error" do
        expect { create_list_partition_of }.to raise_error(NotImplementedError, "#create_list_partition_of is not implemented")
      end
    end

    context "with postgres adapter" do
      after { connection.execute("DROP TABLE IF EXISTS #{parent_table_name} CASCADE") }

      subject(:sql_dump) do
        create_list_partition_of
        PgDumpHelper.dump_table_structure(child_table_name)
      end

      context "identifier based partition" do
        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
            FOR VALUES IN ('1', '2', '3', '4');
          SQL
        end

        let(:primary_key_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name}
            ADD CONSTRAINT #{child_table_name}_pkey PRIMARY KEY (id);
          SQL
        end

        let(:primary_key_default_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name} ALTER COLUMN id
            SET DEFAULT nextval('#{parent_table_name}_id_seq'::regclass);
          SQL
        end

        before { connection.create_list_partition(parent_table_name, partition_key: :id) }

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates primary key statement" do
          expect(sql_dump).to include(primary_key_statement)
        end

        it "generates primary key default value statement" do
          expect(sql_dump).to include(primary_key_default_statement)
        end

        it "does not generate create index statement" do
          expect(sql_dump).to_not include("CREATE INDEX")
        end
      end

      context "boolean based partition" do
        let(:keyword_args) do
          {
            values: true
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
            FOR VALUES IN (true);
          SQL
        end

        let(:primary_key_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name}
            ADD CONSTRAINT #{child_table_name}_pkey PRIMARY KEY (id);
          SQL
        end

        let(:primary_key_default_statement) do
          <<-SQL.squish
            ALTER TABLE ONLY #{child_table_name} ALTER COLUMN id
            SET DEFAULT nextval('#{parent_table_name}_id_seq'::regclass);
          SQL
        end

        before do
          connection.create_list_partition(parent_table_name, partition_key: :active) do |t|
            t.boolean :active, null: false, default: true
          end
        end

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "generates primary key statement" do
          expect(sql_dump).to include(primary_key_statement)
        end

        it "generates primary key default value statement" do
          expect(sql_dump).to include(primary_key_default_statement)
        end

        it "does not generate create index statement" do
          expect(sql_dump).to_not include("CREATE INDEX")
        end
      end
    end
  end

  describe "#attach_range_partition" do
    let(:parent_table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:child_table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:keyword_args) do
      {
        start_range: 1,
        end_range: 10
      }
    end

    subject(:attach_range_partition) { connection.attach_range_partition(parent_table_name, child_table_name, keyword_args) }

    context "with non-postgres adapter" do
      before { allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance) }

      it "raises not implemented error" do
        expect { attach_range_partition }.to raise_error(NotImplementedError, "#attach_range_partition is not implemented")
      end
    end

    context "with postgres adapter" do
      let(:create_table_statement) do
        <<-SQL.squish
          CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
          FOR VALUES FROM ('1') TO ('10');
        SQL
      end

      before do
        connection.create_range_partition(parent_table_name, partition_key: :id)
        connection.execute("CREATE TABLE #{child_table_name} (LIKE #{parent_table_name})")
      end

      after { connection.execute("DROP TABLE IF EXISTS #{parent_table_name} CASCADE") }

      subject(:sql_dump) do
        attach_range_partition
        PgDumpHelper.dump_table_structure(child_table_name)
      end

      it "generates create table statement" do
        expect(sql_dump).to include(create_table_statement)
      end
    end
  end

  describe "#attach_list_partition" do
    let(:parent_table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:child_table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:keyword_args) do
      {
        values: [1, 2]
      }
    end

    subject(:attach_list_partition) { connection.attach_list_partition(parent_table_name, child_table_name, keyword_args) }

    context "with non-postgres adapter" do
      before { allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance) }

      it "raises not implemented error" do
        expect { attach_list_partition }.to raise_error(NotImplementedError, "#attach_list_partition is not implemented")
      end
    end

    context "with postgres adapter" do
      let(:create_table_statement) do
        <<-SQL.squish
          CREATE TABLE #{child_table_name} PARTITION OF #{parent_table_name}
          FOR VALUES IN ('1', '2');
        SQL
      end

      before do
        connection.create_list_partition(parent_table_name, partition_key: :id)
        connection.execute("CREATE TABLE #{child_table_name} (LIKE #{parent_table_name})")
      end

      after { connection.execute("DROP TABLE IF EXISTS #{parent_table_name} CASCADE") }

      subject(:sql_dump) do
        attach_list_partition
        PgDumpHelper.dump_table_structure(child_table_name)
      end

      it "generates create table statement" do
        expect(sql_dump).to include(create_table_statement)
      end
    end
  end

  describe "#detach_partition" do
    let(:parent_table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:child_table_name) { "t_#{SecureRandom.hex(10)}" }

    subject(:detach_partition) { connection.detach_partition(parent_table_name, child_table_name) }

    context "with non-postgres adapter" do
      before { allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance) }

      it "raises not implemented error" do
        expect { detach_partition }.to raise_error(NotImplementedError, "#detach_partition is not implemented")
      end
    end

    context "with postgres adapter" do
      let(:create_table_statement) do
        <<-SQL.squish
          CREATE TABLE #{child_table_name} (
              id bigint DEFAULT nextval('#{parent_table_name}_id_seq'::regclass) NOT NULL
          );
        SQL
      end

      before do
        connection.create_list_partition(parent_table_name, partition_key: :id)

        connection.create_list_partition_of(
          parent_table_name,
          partition_key: :id,
          values: [1, 2],
          name: child_table_name
        )
      end

      after do
        connection.execute("DROP TABLE IF EXISTS #{parent_table_name} CASCADE")
        connection.execute("DROP TABLE IF EXISTS #{child_table_name} CASCADE")
      end

      subject(:sql_dump) do
        detach_partition
        PgDumpHelper.dump_table_structure(child_table_name)
      end

      it "generates create table statement" do
        expect(sql_dump).to include(create_table_statement)
      end
    end
  end
end
