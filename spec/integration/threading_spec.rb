# frozen_string_literal: true

require "spec_helper"
require "thread"

RSpec.describe "threading" do
  let!(:model) { BigintDateRange }
  let!(:table_name) { model.table_name }
  let!(:child_table_name) { "#{table_name}_c" }
  let!(:current_date) { Date.current }
  let!(:current_time) { Time.now }

  before do
    allow(PgParty.cache).to receive(:clear!)
    PgParty.config.caching_ttl = 5
    Timecop.travel(current_date + 12.hours)
  end

  describe ".partitions" do
    it "eventually detects new partitions" do
      threads = 20.times.map do
        Thread.new do
          partitions = nil

          6.times do
            sleep 1
            partitions = model.partitions
          end

          if partitions.size == 3
            Thread.current[:status] = "success"
          else
            Thread.current[:status] = "failed"
          end
        end
      end

      # init cache
      model.partitions

      model.create_partition(
        start_range: current_date + 2.days,
        end_range: current_date + 3.days,
        name: child_table_name,
      )

      expect(model.partitions.size).to eq(2)

      threads.map(&:join).each do |t|
        expect(t[:status]).to eq("success")
      end

      expect(model.partitions.size).to eq(3)
    end
  end

  describe ".in_partition" do
    before do
      (0..23).each do |i|
        model.create!(
          created_at: current_time + i.hours,
          updated_at: current_time + i.hours,
        )
      end
    end

    it "concurrently queries data" do
      threads = 20.times.map do
        Thread.new do
          partition_a_data = nil
          partition_b_data = nil

          6.times do
            sleep 1
            partition_a_data = model.in_partition("#{table_name}_a").all
            partition_b_data = model.in_partition("#{table_name}_b").all
          end

          if partition_a_data.count == 13 && partition_b_data.count == 13
            Thread.current[:status] = "success"
          else
            Thread.current[:status] = "failed"
          end
        end
      end

      model.create!(
        created_at: current_time,
        updated_at: current_time,
      )

      model.create!(
        created_at: current_time + 12.hours,
        updated_at: current_time + 12.hours,
      )

      threads.map(&:join).each do |t|
        expect(t[:status]).to eq("success")
      end
    end
  end
end
