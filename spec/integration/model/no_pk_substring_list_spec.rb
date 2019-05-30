# frozen_string_literal: true

require "spec_helper"

RSpec.describe NoPkSubstringList do
  let(:connection) { described_class.connection }
  let(:schema_cache) { connection.schema_cache }
  let(:table_name) { described_class.table_name }

  describe ".primary_key" do
    subject { described_class.primary_key }

    it { is_expected.to be_nil }
  end

  describe ".create" do
    let(:some_string) { "a_foo" }

    subject { described_class.create!(some_string: some_string) }

    context "when partition key in range" do
      its(:some_string) { is_expected.to eq(some_string) }
    end

    context "when partition key outside range" do
      let(:some_string) { "e_foo" }

      it "raises error" do
        expect { subject }.to raise_error(ActiveRecord::StatementInvalid, /PG::CheckViolation/)
      end
    end
  end

  describe ".partitions" do
    subject { described_class.partitions }

    it { is_expected.to contain_exactly("#{table_name}_a", "#{table_name}_b") }
  end

  describe ".create_partition" do
    let(:values) { ["e", "f"] }
    let(:child_table_name) { "#{table_name}_c" }

    subject(:create_partition) { described_class.create_partition(values: values, name: child_table_name) }
    subject(:partitions) { described_class.partitions }
    subject(:child_table_exists) { schema_cache.data_source_exists?(child_table_name) }

    before do
      schema_cache.clear!
      described_class.partitions
    end

    after { connection.drop_table(child_table_name) if child_table_exists }

    context "when ranges do not overlap" do
      it "returns table name and adds it to partition list" do
        expect(create_partition).to eq(child_table_name)

        expect(partitions).to contain_exactly(
          "#{table_name}_a",
          "#{table_name}_b",
          "#{table_name}_c"
        )
      end
    end

    context "when name not provided" do
      let(:child_table_name) { create_partition }

      subject(:create_partition) { described_class.create_partition(values: values) }

      it "returns table name and adds it to partition list" do
        expect(create_partition).to match(/^#{table_name}_\w{7}$/)

        expect(partitions).to contain_exactly(
          "#{table_name}_a",
          "#{table_name}_b",
          child_table_name,
        )
      end
    end

    context "when ranges overlap" do
      let(:values) { ["b", "c"] }

      it "raises error and cleans up intermediate table" do
        expect { create_partition }.to raise_error(ActiveRecord::StatementInvalid, /PG::InvalidObjectDefinition/)
        expect(child_table_exists).to eq(false)
      end
    end
  end

  describe ".in_partition" do
    let(:child_table_name) { "#{table_name}_a" }

    subject { described_class.in_partition(child_table_name) }

    its(:table_name) { is_expected.to eq(child_table_name) }
    its(:name)       { is_expected.to eq(described_class.name) }
    its(:new)        { is_expected.to be_an_instance_of(described_class) }
    its(:allocate)   { is_expected.to be_an_instance_of(described_class) }

    describe "query methods" do
      let!(:record_one) { described_class.create!(some_string: "a_foo") }
      let!(:record_two) { described_class.create!(some_string: "b_foo") }
      let!(:record_three) { described_class.create!(some_string: "c_foo") }

      describe ".all" do
        subject { described_class.in_partition(child_table_name).all }

        it do
          is_expected.to contain_exactly(
            an_object_having_attributes(some_string: "a_foo"),
            an_object_having_attributes(some_string: "b_foo"),
          )
        end
      end

      describe ".where" do
        subject { described_class.in_partition(child_table_name).where(some_string: "a_foo") }

        it do
          is_expected.to contain_exactly(
            an_object_having_attributes(some_string: "a_foo")
          )
        end
      end
    end
  end

  describe ".partition_key_in" do
    let(:values) { ["a", "b"] }

    let!(:record_one) { described_class.create!(some_string: "a_foo") }
    let!(:record_two) { described_class.create!(some_string: "b_foo") }
    let!(:record_three) { described_class.create!(some_string: "c_foo") }

    subject { described_class.partition_key_in(values) }

    context "when spanning a single partition" do
      it do
        is_expected.to contain_exactly(
          an_object_having_attributes(some_string: "a_foo"),
          an_object_having_attributes(some_string: "b_foo"),
        )
      end
    end

    context "when spanning multiple partitions" do
      let(:values) { ["a", "b", "c", "d"] }

      it do
        is_expected.to contain_exactly(
          an_object_having_attributes(some_string: "a_foo"),
          an_object_having_attributes(some_string: "b_foo"),
          an_object_having_attributes(some_string: "c_foo"),
        )
      end
    end

    context "when chaining methods" do
      subject { described_class.partition_key_in(values).where(some_string: "a_foo") }

      it do
        is_expected.to contain_exactly(
          an_object_having_attributes(some_string: "a_foo")
        )
      end
    end
  end

  describe ".partition_key_eq" do
    let(:partition_key) { "a" }

    let!(:record_one) { described_class.create!(some_string: "a_foo") }
    let!(:record_two) { described_class.create!(some_string: "c_foo") }

    subject { described_class.partition_key_eq(partition_key) }

    context "when partition key in first partition" do
      it do
        is_expected.to contain_exactly(
          an_object_having_attributes(some_string: "a_foo")
        )
      end
    end

    context "when partition key in second partition" do
      let(:partition_key) { "c" }

      it do
        is_expected.to contain_exactly(
          an_object_having_attributes(some_string: "c_foo")
        )
      end
    end

    # TODO: write more tests like this
    context "when partition key in first partition and table is aliased" do
      subject do
        described_class
          .select("*")
          .from(described_class.arel_table.alias)
          .partition_key_eq(partition_key)
      end

      it do
        is_expected.to contain_exactly(
          an_object_having_attributes(some_string: "a_foo")
        )
      end
    end

    context "when table alias not resolvable" do
      subject do
        described_class
          .select("*")
          .from("garbage")
          .partition_key_eq(partition_key)
      end

      it { expect { subject }.to raise_error("could not find arel table in current scope") }
    end
  end
end
