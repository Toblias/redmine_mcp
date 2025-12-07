# frozen_string_literal: true

module RedmineMcp
  # Tracks SSE connections per user to prevent resource exhaustion.
  # Uses stdlib Mutex + Hash for thread safety without external dependencies.
  #
  # Note: Thread-safe within a single Puma process. For multi-process
  # deployments, consider Redis-backed tracking instead.
  #
  class SseConnectionTracker
    MAX_CONNECTIONS_PER_USER = 3

    class << self
      def mutex
        @mutex ||= Mutex.new
      end

      def connections
        @connections ||= Hash.new(0)
      end

      # Attempt to acquire a connection slot for the user.
      #
      # @param user_id [Integer] User ID
      # @return [Boolean] true if connection allowed, false if limit reached
      def acquire(user_id)
        mutex.synchronize do
          return false if connections[user_id] >= MAX_CONNECTIONS_PER_USER

          connections[user_id] += 1
          true
        end
      end

      # Release a connection slot for the user.
      # Must be called in an ensure block when SSE connection closes.
      #
      # @param user_id [Integer] User ID
      def release(user_id)
        mutex.synchronize do
          connections[user_id] -= 1
          connections.delete(user_id) if connections[user_id] <= 0
        end
      end

      # Get the current connection count for a user.
      #
      # @param user_id [Integer] User ID
      # @return [Integer] Current connection count
      def count_for(user_id)
        mutex.synchronize { connections[user_id] }
      end

      # Reset all tracking (for testing only)
      def reset!
        mutex.synchronize do
          @connections = Hash.new(0)
        end
      end
    end
  end
end
