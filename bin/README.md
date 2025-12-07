# Redmine MCP Plugin - Validation Scripts

This directory contains scripts to validate and test the Redmine MCP plugin installation.

## Overview

| Script | Purpose | Environment | Time |
|--------|---------|-------------|------|
| `validate_installation.rb` | Comprehensive health check | Standalone | ~5 sec |
| `smoke_test.rb` | Quick validation | Standalone/Rails | ~1 sec |
| `test_mcp_endpoint.sh` | HTTP endpoint testing | Running server | ~10 sec |

## Scripts

### 1. validate_installation.rb

**Purpose:** Comprehensive installation validation with detailed health checks.

**What it checks:**
- Ruby version compatibility (>= 2.7)
- Redmine version compatibility (>= 5.0)
- Plugin file structure integrity
- All required files exist
- Tool files exist and load correctly
- Prompt files exist and load correctly
- Registry population and health
- JSON-RPC configuration
- Error classes are defined

**Usage:**
```bash
# From Redmine root
ruby plugins/redmine_mcp/bin/validate_installation.rb

# From plugin directory
cd plugins/redmine_mcp
ruby bin/validate_installation.rb
```

**Sample Output:**
```
Redmine MCP Plugin - Installation Validator
Plugin root: /path/to/redmine/plugins/redmine_mcp

Checking Ruby version (>= 2.7)... OK
Checking Redmine installation... OK
Checking Plugin file structure... OK
Checking Tool files... OK
Checking Prompt files... OK
Checking Plugin loading and registry... OK
  Registered tools:
    - create_issue
    - get_current_user
    - get_issue
    [...]

=== Validation Summary ===
Total checks: 10
Passed: 10
Failed: 0

All checks passed! Plugin is ready to use.
```

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more checks failed

---

### 2. smoke_test.rb

**Purpose:** Quick smoke test to verify plugin loads and tools/prompts are registered.

**What it does:**
- Loads the plugin
- Lists all registered tools (count and names)
- Lists all registered prompts (count and names)
- Shows registry health status
- Tests sample tool/prompt schema generation

**Usage:**
```bash
# From Redmine root
ruby plugins/redmine_mcp/bin/smoke_test.rb

# From plugin directory
cd plugins/redmine_mcp
ruby bin/smoke_test.rb

# From Rails console
load 'plugins/redmine_mcp/bin/smoke_test.rb'
```

**Sample Output:**
```
=== Redmine MCP Plugin - Smoke Test ===

Registry Status:
  Frozen: Yes
  Tools registered: 22
  Prompts registered: 5

Registered Tools (22):
  ✓ create_issue
    Create a new issue in a project
  ✓ get_current_user
    Get current authenticated user profile
  [...]

Registered Prompts (5):
  ✓ bug_report
    Generate a comprehensive bug report template
  [...]

✓ Smoke test PASSED
```

**Exit Codes:**
- `0` - Smoke test passed
- `1` - Smoke test failed

---

### 3. test_mcp_endpoint.sh

**Purpose:** Test HTTP endpoints to verify the MCP server responds correctly to protocol requests.

**Requirements:**
- `curl` (required)
- `jq` (optional, for pretty JSON output)
- Running Redmine instance
- Valid API key

**Environment Variables:**
- `REDMINE_URL` - Base URL of Redmine (e.g., `http://localhost:3000`)
- `API_KEY` - Your Redmine API key

**What it tests:**
1. Health check endpoint (`GET /mcp/health`)
2. MCP initialize handshake
3. Ping request
4. Tools list
5. Prompts list
6. Resource templates list
7. Error handling (invalid method)

**Usage:**
```bash
# Set environment variables
export REDMINE_URL="http://localhost:3000"
export API_KEY="your_api_key_here"

# Run tests
./bin/test_mcp_endpoint.sh

# Or inline
REDMINE_URL="http://localhost:3000" API_KEY="your_key" ./bin/test_mcp_endpoint.sh
```

**Sample Output:**
```
=== Redmine MCP Endpoint Tests ===

Checking prerequisites...
✓ curl is available
✓ jq is available (will parse JSON responses)
✓ REDMINE_URL is set: http://localhost:3000
✓ API_KEY is set: 1a2b3c4d...

Test 1: Health Check
Testing GET /mcp/health... ✓ PASSED (HTTP 200)
  Response:
    {
      "status": "ok",
      "plugin": "redmine_mcp",
      "version": "1.0.0"
    }

Test 2: MCP Initialize
Testing POST /mcp (initialize)... ✓ PASSED (HTTP 200)
  Response:
    {
      "jsonrpc": "2.0",
      "id": 1,
      "result": {
        "protocolVersion": "2024-11-05",
        [...]
      }
    }

[...]

=== Test Summary ===
Total tests: 7
Passed: 7
Failed: 0

All tests passed! MCP endpoints are working correctly.
```

**Exit Codes:**
- `0` - All tests passed
- `1` - One or more tests failed
- `2` - Missing requirements

---

## Recommended Workflow

### After Installation

1. **Run validate_installation.rb first:**
   ```bash
   ruby plugins/redmine_mcp/bin/validate_installation.rb
   ```
   This ensures all files are in place and the plugin loads correctly.

2. **Run smoke_test.rb for quick checks:**
   ```bash
   ruby plugins/redmine_mcp/bin/smoke_test.rb
   ```
   Fast verification that tools and prompts are registered.

3. **Start Redmine and test endpoints:**
   ```bash
   # Start Redmine server (if not running)
   bundle exec rails server

   # In another terminal
   export REDMINE_URL="http://localhost:3000"
   export API_KEY="your_api_key"
   ./plugins/redmine_mcp/bin/test_mcp_endpoint.sh
   ```

### During Development

- Use `smoke_test.rb` for quick iterations
- Use `validate_installation.rb` after adding new tools/prompts
- Use `test_mcp_endpoint.sh` after changing JSON-RPC handlers

### Troubleshooting

If any script fails:

1. Check Redmine logs:
   ```bash
   tail -f log/development.log
   # or
   tail -f log/production.log
   ```

2. Verify plugin is enabled:
   - Go to Redmine: Administration → Plugins
   - Check "Redmine MCP Server" is listed

3. Check routes are loaded:
   ```bash
   bundle exec rake routes | grep mcp
   ```

4. Verify Ruby/Redmine versions:
   ```bash
   ruby -v  # Should be 2.7+
   # In Rails console
   Redmine::VERSION
   ```

---

## API Key Setup

To get an API key for testing:

1. Log into Redmine
2. Go to "My account" (top right)
3. Click "Show" under API access key
4. Copy the key
5. Use it in `test_mcp_endpoint.sh`:
   ```bash
   export API_KEY="your_copied_key"
   ```

---

## Continuous Integration

These scripts can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Validate MCP Plugin
  run: |
    ruby plugins/redmine_mcp/bin/validate_installation.rb
    ruby plugins/redmine_mcp/bin/smoke_test.rb

- name: Test MCP Endpoints
  env:
    REDMINE_URL: http://localhost:3000
    API_KEY: ${{ secrets.REDMINE_API_KEY }}
  run: |
    ./plugins/redmine_mcp/bin/test_mcp_endpoint.sh
```

---

## Script Maintenance

When adding new tools or prompts:

1. Update minimum counts in scripts if needed:
   - `validate_installation.rb` expects >= 22 tools
   - `smoke_test.rb` expects >= 22 tools, >= 5 prompts

2. Test the new additions:
   ```bash
   ruby plugins/redmine_mcp/bin/smoke_test.rb
   ```

3. Verify they appear in the output lists

---

## Support

If you encounter issues:

1. Run all three validation scripts
2. Check the output for specific error messages
3. Review Redmine logs
4. Consult the main plugin README
5. Report issues with the full validation output
