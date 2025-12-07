# frozen_string_literal: true

module RedmineMcp
  # Server-Sent Events helper class
  # Rails does not provide a built-in SSE class, so we implement our own.
  #
  # SSE format:
  #   event: <event-type>\n
  #   id: <event-id>\n
  #   retry: <reconnection-time-ms>\n
  #   data: <line1>\n
  #   data: <line2>\n
  #   \n
  #
  class SSE
    def initialize(stream)
      @stream = stream
    end

    # Write an SSE event to the stream
    #
    # @param data [String] Event data (can be multiline, each line prefixed with "data:")
    # @param event [String, nil] Event type name (optional)
    # @param id [String, nil] Event ID for client reconnection (optional)
    # @param retry_ms [Integer, nil] Reconnection time in milliseconds (optional)
    def write(data, event: nil, id: nil, retry_ms: nil)
      @stream.write("event: #{event}\n") if event
      @stream.write("id: #{id}\n") if id
      @stream.write("retry: #{retry_ms}\n") if retry_ms

      # Handle multiline data - each line needs "data:" prefix
      data.to_s.each_line do |line|
        @stream.write("data: #{line.chomp}\n")
      end

      # Empty line signals end of event
      @stream.write("\n")
    end

    # Close the underlying stream
    def close
      @stream.close
    rescue IOError
      # Stream already closed, ignore
    end
  end
end
