require "thread"

module PgParty
  class Cache
    LOCK = Mutex.new

    class << self
      def clear!
        LOCK.synchronize { store.clear }

        nil
      end

      def fetch_model(key, child_table, &block)
        LOCK.synchronize do
          store[key][:models][child_table.to_sym] ||= block.call
        end
      end

      def fetch_partitions(key, &block)
        LOCK.synchronize do
          store[key][:partitions] ||= block.call
        end
      end

      private

      def store
        # automatically initialize a new hash when
        # accessing an object id that doesn't exist
        @store ||= Hash.new { |h, k| h[k] = { models: {}, partitions: nil } }
      end
    end
  end
end
