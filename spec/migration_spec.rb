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

  describe "#create_master_partition" do
    let(:table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:keyword_args) { {} }
    let(:block) do
      ->(t) do
        t.timestamps
      end
    end

    subject(:create_master_partition) { connection.create_master_partition(table_name, keyword_args, &block) }

    context "with non-postgres adapter" do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance)
      end

      it "raises not implemented error" do
        expect { create_master_partition }.to raise_error(NotImplementedError, "#create_master_partition is not implemented")
      end
    end

    context "with postgres adapter" do
      after do
        connection.drop_table(table_name, if_exists: true, force: true)
      end

      subject(:sql_dump) do
        create_master_partition
        PgDumpHelper.dump_table_structure(table_name)
      end

      context "with defaults" do
        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                id bigint NOT NULL,
                created_at timestamp without time zone NOT NULL,
                updated_at timestamp without time zone NOT NULL
            )
            PARTITION BY RANGE (((created_at)::date));
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
        let(:uuid_function) { Rails::VERSION::STRING >= "5.1" ? "gen_random_uuid()" : "uuid_generate_v4()" }
        let(:keyword_args) do
          {
            id: :uuid
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                id uuid DEFAULT #{uuid_function} NOT NULL,
                created_at timestamp without time zone NOT NULL,
                updated_at timestamp without time zone NOT NULL
            )
            PARTITION BY RANGE (((created_at)::date));
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
            id: false
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                created_at timestamp without time zone NOT NULL,
                updated_at timestamp without time zone NOT NULL
            )
            PARTITION BY RANGE (((created_at)::date));
          SQL
        end

        it "generates create table statement" do
          expect(sql_dump).to include(create_table_statement)
        end

        it "does not generate sequence statement" do
          expect(sql_dump).to_not include("CREATE SEQUENCE")
        end
      end

      context "with sequential id range" do
        let(:block) { ->(t) {} }
        let(:keyword_args) do
          {
            range_key: :id
          }
        end

        let(:create_table_statement) do
          <<-SQL.squish
            CREATE TABLE #{table_name} (
                id bigint NOT NULL
            )
            PARTITION BY RANGE (id);
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

  describe "#create_child_partition" do
    let(:parent_table_name) { "t_#{SecureRandom.hex(10)}" }
    let(:child_table_name) { create_child_partition }
    let(:current_date) { Date.current }
    let(:start_range) { current_date }
    let(:end_range) { current_date + 1.month }
    let(:additional_options) { {} }
    let(:keyword_args) do
      additional_options.merge(
        start_range: start_range,
        end_range: end_range
      )
    end

    subject(:create_child_partition) { connection.create_child_partition(parent_table_name, keyword_args) }

    context "with non-postgres adapter" do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_return(custom_adapter_instance)
      end

      it "raises not implemented error" do
        expect { create_child_partition }.to raise_error(NotImplementedError, "#create_child_partition is not implemented")
      end
    end

    context "with postgres adapter" do
      after do
        connection.drop_table(parent_table_name, if_exists: true, force: true)
      end

      subject(:sql_dump) do
        create_child_partition
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
          connection.create_master_partition(parent_table_name) do |t|
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
      end

      context "with sequential id range" do
        let(:start_range) { 1 }
        let(:end_range) { 100 }
        let(:additional_options) do
          {
            range_key: :id
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
          connection.create_master_partition(parent_table_name, range_key: :id)
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
      end
    end
  end
end
