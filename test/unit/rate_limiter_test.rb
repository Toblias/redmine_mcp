# frozen_string_literal: true

require_relative '../test_helper'

class RateLimiterTest < ActiveSupport::TestCase
  def setup
    clear_rate_limiter
  end

  def teardown
    clear_rate_limiter
  end

  # ========== Basic Rate Limiting Tests ==========

  test 'allows requests under limit' do
    user_id = 1

    assert_nothing_raised do
      10.times do
        RedmineMcp::RateLimiter.check!(user_id, limit: 60)
      end
    end
  end

  test 'raises error when limit exceeded' do
    user_id = 2

    assert_raises RedmineMcp::RateLimitExceeded do
      61.times do
        RedmineMcp::RateLimiter.check!(user_id, limit: 60)
      end
    end
  end

  test 'tracks separate limits per user' do
    user1 = 1
    user2 = 2

    # User 1 makes 60 requests
    60.times do
      RedmineMcp::RateLimiter.check!(user1, limit: 60)
    end

    # User 2 should still be able to make requests
    assert_nothing_raised do
      RedmineMcp::RateLimiter.check!(user2, limit: 60)
    end
  end

  # ========== Batch Counting Tests ==========

  test 'counts batch requests correctly' do
    user_id = 3

    # Make 20 single requests
    20.times do
      RedmineMcp::RateLimiter.check!(user_id, count: 1, limit: 60)
    end

    # Make a batch of 40 requests - should still be under limit
    assert_nothing_raised do
      RedmineMcp::RateLimiter.check!(user_id, count: 40, limit: 60)
    end

    # Next request should exceed limit
    assert_raises RedmineMcp::RateLimitExceeded do
      RedmineMcp::RateLimiter.check!(user_id, count: 1, limit: 60)
    end
  end

  # ========== Cache Expiration Tests ==========

  test 'resets after cache expiration' do
    user_id = 4

    # Fill the limit
    60.times do
      RedmineMcp::RateLimiter.check!(user_id, limit: 60)
    end

    # Should raise now
    assert_raises RedmineMcp::RateLimitExceeded do
      RedmineMcp::RateLimiter.check!(user_id, limit: 60)
    end

    # Simulate cache expiration by clearing
    clear_rate_limiter

    # Should work again
    assert_nothing_raised do
      RedmineMcp::RateLimiter.check!(user_id, limit: 60)
    end
  end

  # ========== Edge Cases Tests ==========

  test 'handles zero count' do
    user_id = 5

    assert_nothing_raised do
      RedmineMcp::RateLimiter.check!(user_id, count: 0, limit: 60)
    end
  end

  test 'handles very low limit' do
    user_id = 6

    # With limit of 1, second request should fail
    RedmineMcp::RateLimiter.check!(user_id, limit: 1)

    assert_raises RedmineMcp::RateLimitExceeded do
      RedmineMcp::RateLimiter.check!(user_id, limit: 1)
    end
  end

  test 'handles very high count' do
    user_id = 7

    # Single request with count exceeding limit
    assert_raises RedmineMcp::RateLimitExceeded do
      RedmineMcp::RateLimiter.check!(user_id, count: 100, limit: 60)
    end
  end
end
