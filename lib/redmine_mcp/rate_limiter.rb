# frozen_string_literal: true

module RedmineMcp
  # Token bucket rate limiter using Rails.cache.
  # Limits requests per user per minute to prevent runaway AI loops.
  #
  # Cache backend compatibility:
  #   - Redis/Memcached: Atomic increment, recommended for production
  #   - MemoryStore: Works but not shared across Puma workers
  #   - FileStore: Non-atomic fallback, race conditions possible
  #   - NullStore: In-memory fallback for testing
  #
  class RateLimiter
    DEFAULT_LIMIT = 60 # requests per minute (fallback)

    # In-memory storage for NullStore cache (test environment)
    @memory_store = {}
    @memory_store_mutex = Mutex.new

    class << self
      # Check rate limit and raise if exceeded.
      #
      # @param user_id [Integer] User ID to rate limit
      # @param count [Integer] Number of requests (for batch counting)
      # @param limit [Integer] Max requests per minute (from settings)
      # @raise [RateLimitExceeded] if limit exceeded
      def check!(user_id, count: 1, limit: DEFAULT_LIMIT)
        # Namespaced key to avoid collision in shared cache environments
        key = "redmine_mcp:rate_limit:#{user_id}"

        current = increment_counter(key, count)
        raise RedmineMcp::RateLimitExceeded if current > limit
      end

      # Clear rate limit counters (for testing)
      def clear!
        @memory_store_mutex.synchronize { @memory_store.clear }
        Rails.cache.clear rescue nil
      end

      private

      def increment_counter(key, count)
        # Try Rails.cache first
        if cache_supports_increment?
          result = Rails.cache.increment(key, count, expires_in: 1.minute)
          return result if result
        end

        # Try read/write approach
        if cache_supports_read_write?
          value = Rails.cache.read(key)
          if value
            new_value = value + count
            Rails.cache.write(key, new_value, expires_in: 1.minute)
            return new_value
          else
            Rails.cache.write(key, count, expires_in: 1.minute)
            # Verify write worked
            return count if Rails.cache.read(key) == count
          end
        end

        # Fallback to in-memory store (NullStore or broken cache)
        use_memory_store(key, count)
      end

      def cache_supports_increment?
        Rails.cache.respond_to?(:increment) &&
          !Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
      end

      def cache_supports_read_write?
        !Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
      end

      def use_memory_store(key, count)
        @memory_store_mutex.synchronize do
          entry = @memory_store[key]
          now = Time.now.to_i

          if entry.nil? || entry[:expires_at] < now
            # New or expired entry
            @memory_store[key] = { value: count, expires_at: now + 60 }
            count
          else
            # Increment existing entry
            entry[:value] += count
            entry[:value]
          end
        end
      end
    end
  end
end
