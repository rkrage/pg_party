require "thread"

module PgParty
  class Cache
    LOCK = Mutex.new

    class << self
      def clear!
        LOCK.synchronize { store.clear }

        nil
      end

      def fetch_model(parent_table, child_table, &block)
        LOCK.synchronize do
          store[parent_table.to_sym][:models][child_table.to_sym] ||= block.call
        end
      end

      def fetch_partitions(table_name, &block)
        LOCK.synchronize do
          store[table_name.to_sym][:partitions] ||= block.call
        end
      end

      private

      def store
        # automatically initialize a new hash when
        # accessing a table name that doesn't exist
        @store ||= Hash.new { |h, k| h[k] = { models: {}, partitions: nil } }
      end
    end
  end
end
