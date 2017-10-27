require "thread"

module PgParty
  class Cache
    LOCK = Mutex.new

    class << self
      def clear!
        LOCK.synchronize do
          partitions.clear
          models.clear
        end

        nil
      end

      def clear_partitions!
        LOCK.synchronize { partitions.clear }

        nil
      end

      def clear_models!
        LOCK.synchronize { models.clear }

        nil
      end

      def fetch_model(parent_table, child_table, &block)
        LOCK.synchronize do
          models[parent_table.to_sym][child_table.to_sym] ||= block.call
        end
      end

      def fetch_partitions(table_name, &block)
        LOCK.synchronize do
          partitions[table_name.to_sym] ||= block.call
        end
      end

      private

      def partitions
        @partitions ||= {}
      end

      def models
        # initialize a new hash as the default value
        @models ||= Hash.new { |h, k| h[k] = {} }
      end
    end
  end
end
