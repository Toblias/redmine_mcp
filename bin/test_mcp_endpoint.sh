#!/bin/bash
# Redmine MCP Plugin - HTTP Endpoint Test Script
#
# This script tests the MCP HTTP endpoints to verify the server is responding
# correctly to MCP protocol requests.
#
# Usage:
#   export REDMINE_URL="http://localhost:3000"
#   export API_KEY="your_api_key_here"
#   ./bin/test_mcp_endpoint.sh
#
# Or inline:
#   REDMINE_URL="http://localhost:3000" API_KEY="your_key" ./bin/test_mcp_endpoint.sh
#
# Requirements:
#   - curl (for HTTP requests)
#   - jq (for JSON parsing, optional but recommended)
#   - REDMINE_URL environment variable
#   - API_KEY environment variable
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#   2 - Missing requirements

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Track test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Check if jq is available
HAS_JQ=false
if command -v jq &> /dev/null; then
  HAS_JQ=true
fi

# Print colored output
print_header() {
  echo -e "${BOLD}$1${RESET}"
}

print_success() {
  echo -e "${GREEN}✓ $1${RESET}"
}

print_error() {
  echo -e "${RED}✗ $1${RESET}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${RESET}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${RESET}"
}

# Validate prerequisites
validate_prerequisites() {
  print_header "Checking prerequisites..."

  # Check curl
  if ! command -v curl &> /dev/null; then
    print_error "curl is not installed"
    exit 2
  fi
  print_success "curl is available"

  # Check jq (optional but recommended)
  if $HAS_JQ; then
    print_success "jq is available (will parse JSON responses)"
  else
    print_warning "jq is not installed (JSON responses will be raw)"
  fi

  # Check REDMINE_URL
  if [ -z "${REDMINE_URL:-}" ]; then
    print_error "REDMINE_URL environment variable is not set"
    echo "  Example: export REDMINE_URL=\"http://localhost:3000\""
    exit 2
  fi
  print_success "REDMINE_URL is set: $REDMINE_URL"

  # Check API_KEY
  if [ -z "${API_KEY:-}" ]; then
    print_error "API_KEY environment variable is not set"
    echo "  Example: export API_KEY=\"your_api_key_here\""
    exit 2
  fi
  print_success "API_KEY is set: ${API_KEY:0:8}..."

  echo ""
}

# Run a test
run_test() {
  local test_name="$1"
  local url="$2"
  local method="$3"
  local data="$4"
  local expected_status="${5:-200}"

  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "Testing $test_name... "

  # Create temp files for response
  local response_file=$(mktemp)
  local headers_file=$(mktemp)

  # Make request
  if [ "$method" = "GET" ]; then
    http_code=$(curl -s -w "%{http_code}" \
      -H "X-Redmine-API-Key: $API_KEY" \
      -H "Accept: application/json" \
      -o "$response_file" \
      -D "$headers_file" \
      "$url")
  else
    http_code=$(curl -s -w "%{http_code}" \
      -X "$method" \
      -H "X-Redmine-API-Key: $API_KEY" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$data" \
      -o "$response_file" \
      -D "$headers_file" \
      "$url")
  fi

  # Check status code
  if [ "$http_code" = "$expected_status" ]; then
    print_success "PASSED (HTTP $http_code)"
    TESTS_PASSED=$((TESTS_PASSED + 1))

    # Show response if jq is available
    if $HAS_JQ && [ -s "$response_file" ]; then
      echo "  Response:"
      jq '.' "$response_file" 2>/dev/null | head -20 | sed 's/^/    /'
    fi
  else
    print_error "FAILED (expected HTTP $expected_status, got HTTP $http_code)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$test_name")

    echo "  Response:"
    if $HAS_JQ && [ -s "$response_file" ]; then
      jq '.' "$response_file" 2>/dev/null || cat "$response_file"
    else
      cat "$response_file"
    fi | head -20 | sed 's/^/    /'
  fi

  # Cleanup
  rm -f "$response_file" "$headers_file"
  echo ""
}

# Main execution
print_header "=== Redmine MCP Endpoint Tests ==="
echo ""

validate_prerequisites

MCP_URL="${REDMINE_URL}/mcp"

# Test 1: Health endpoint
print_header "Test 1: Health Check"
run_test "GET /mcp/health" \
  "${MCP_URL}/health" \
  "GET" \
  "" \
  "200"

# Test 2: Initialize handshake
print_header "Test 2: MCP Initialize"
init_request=$(cat <<'EOF'
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "roots": {
        "listChanged": true
      },
      "sampling": {}
    },
    "clientInfo": {
      "name": "test-client",
      "version": "1.0.0"
    }
  }
}
EOF
)

run_test "POST /mcp (initialize)" \
  "$MCP_URL" \
  "POST" \
  "$init_request" \
  "200"

# Test 3: Ping
print_header "Test 3: Ping"
ping_request=$(cat <<'EOF'
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "ping"
}
EOF
)

run_test "POST /mcp (ping)" \
  "$MCP_URL" \
  "POST" \
  "$ping_request" \
  "200"

# Test 4: List tools
print_header "Test 4: List Tools"
tools_list_request=$(cat <<'EOF'
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/list"
}
EOF
)

run_test "POST /mcp (tools/list)" \
  "$MCP_URL" \
  "POST" \
  "$tools_list_request" \
  "200"

# Test 5: List prompts
print_header "Test 5: List Prompts"
prompts_list_request=$(cat <<'EOF'
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "prompts/list"
}
EOF
)

run_test "POST /mcp (prompts/list)" \
  "$MCP_URL" \
  "POST" \
  "$prompts_list_request" \
  "200"

# Test 6: List resource templates
print_header "Test 6: List Resource Templates"
templates_request=$(cat <<'EOF'
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "resources/templates/list"
}
EOF
)

run_test "POST /mcp (resources/templates/list)" \
  "$MCP_URL" \
  "POST" \
  "$templates_request" \
  "200"

# Test 7: Invalid method (should fail gracefully)
print_header "Test 7: Invalid Method (Error Handling)"
invalid_request=$(cat <<'EOF'
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "invalid/method"
}
EOF
)

run_test "POST /mcp (invalid method)" \
  "$MCP_URL" \
  "POST" \
  "$invalid_request" \
  "200"  # JSON-RPC errors still return 200 with error in body

# Print summary
echo ""
print_header "=== Test Summary ==="
echo "Total tests: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${RESET}"
echo -e "${RED}Failed: $TESTS_FAILED${RESET}"

if [ $TESTS_FAILED -eq 0 ]; then
  echo ""
  print_success "All tests passed! MCP endpoints are working correctly."
  echo ""
  print_header "Next Steps:"
  echo "1. Try calling a tool (e.g., get_current_user)"
  echo "2. Test SSE endpoint: curl -H \"X-Redmine-API-Key: \$API_KEY\" \"\$REDMINE_URL/mcp/sse\""
  echo "3. Connect your AI client to the MCP server"
  exit 0
else
  echo ""
  print_error "Some tests failed:"
  for test in "${FAILED_TESTS[@]}"; do
    echo "  - $test"
  done
  echo ""
  print_header "Troubleshooting:"
  echo "1. Check that the Redmine MCP plugin is installed and enabled"
  echo "2. Verify your API key has proper permissions"
  echo "3. Check Redmine logs: log/production.log or log/development.log"
  echo "4. Ensure the plugin routes are loaded: rake routes | grep mcp"
  exit 1
fi
