# frozen_string_literal: true

module RedmineMcp
  # Base error class for all MCP-related errors
  class Error < StandardError; end

  # Raised when user exceeds rate limit (60 requests/minute default)
  class RateLimitExceeded < Error; end

  # Raised when user has too many concurrent SSE connections
  class SseConnectionLimitExceeded < Error; end

  # Raised when write operations are disabled by admin
  class WriteOperationsDisabled < Error; end

  # Raised when user lacks permission for an operation
  class PermissionDenied < Error; end

  # Raised when a requested resource (tool, prompt, record) is not found
  class ResourceNotFound < Error; end

  # Raised when required parameters are missing or invalid
  class InvalidParams < Error; end
end
