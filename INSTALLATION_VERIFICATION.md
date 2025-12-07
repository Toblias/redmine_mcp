# Redmine MCP Plugin - Installation Verification Checklist

This checklist helps verify that the Redmine MCP plugin is installed correctly and functioning properly.

## Version Information

- **Plugin Version:** 1.0.0
- **Release Date:** 2025-12-07
- **Required Redmine Version:** 5.0 or higher
- **Required Ruby Version:** 2.7 or higher

## Pre-Installation Verification

Before installing the plugin, verify these requirements:

### System Requirements

- [ ] Redmine version 5.0 or higher is installed
- [ ] Ruby version 2.7 or higher is available
- [ ] Application server is Puma or Passenger (not Unicorn)
- [ ] User has administrative access to Redmine
- [ ] User can restart the Redmine application server

### Server Configuration

- [ ] Web server (Nginx/Apache) is configured for long-lived SSE connections
- [ ] Firewall allows SSE connections (if applicable)
- [ ] Server has sufficient resources (CPU, memory) for AI workloads

## Installation Steps Verification

Verify each installation step was completed:

### 1. Plugin Files

- [ ] Plugin directory exists at `/path/to/redmine/plugins/redmine_mcp/`
- [ ] All required files are present (see "Required Files" section below)
- [ ] File permissions are correct (readable by Redmine process)

### 2. Application Restart

- [ ] Redmine application was restarted after plugin installation
- [ ] No errors in Redmine logs during startup
- [ ] Plugin appears in **Administration > Plugins** list

### 3. Plugin Configuration

- [ ] Plugin settings page is accessible at **Administration > Plugins > Redmine MCP Server > Configure**
- [ ] All configuration options are displayed correctly
- [ ] Default settings are loaded properly

## Functional Verification

Test core functionality to ensure the plugin works correctly:

### 1. Health Check

Test the health endpoint (no authentication required):

```bash
curl https://your-redmine-instance.com/mcp/health
```

**Expected Response:**
```json
{"status":"ok","server":"redmine-mcp","version":"1.0.0"}
```

- [ ] Health endpoint returns HTTP 200 status
- [ ] Response contains correct version number
- [ ] Response format is valid JSON

### 2. API Authentication

Generate an API key and test authentication:

1. [ ] Log in to Redmine as a regular user
2. [ ] Navigate to **My Account** (top right menu)
3. [ ] API key is visible or can be generated under "API access key"
4. [ ] API key is a valid 40-character hexadecimal string

Test authentication with ping:

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"ping","id":1}' \
  https://your-redmine-instance.com/mcp
```

**Expected Response:**
```json
{"jsonrpc":"2.0","id":1,"result":{}}
```

- [ ] Ping request returns HTTP 200 status
- [ ] Response contains empty result object
- [ ] No authentication errors in logs

### 3. MCP Protocol Handshake

Test MCP initialization:

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}' \
  https://your-redmine-instance.com/mcp
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {"listChanged": false},
      "resources": {"subscribe": false, "listChanged": false},
      "prompts": {"listChanged": false}
    },
    "serverInfo": {
      "name": "redmine-mcp",
      "version": "1.0.0"
    }
  }
}
```

- [ ] Initialize request succeeds
- [ ] Protocol version matches ("2024-11-05")
- [ ] Server version is "1.0.0"
- [ ] All capabilities are declared

### 4. Tools Discovery

List available tools:

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":2}' \
  https://your-redmine-instance.com/mcp
```

**Expected Response:**
- [ ] Returns list of 22 tools
- [ ] Each tool has: name, description, inputSchema
- [ ] Tool categories are represented: issues, projects, time_entries, wiki, users, utility

### 5. Tool Execution

Test a simple tool (list_trackers):

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":3,"params":{"name":"list_trackers","arguments":{}}}' \
  https://your-redmine-instance.com/mcp
```

**Expected Response:**
- [ ] Returns list of issue trackers
- [ ] Each tracker has: id, name, default_status_id
- [ ] Response format matches MCP tool response structure

### 6. Prompts Discovery

List available prompts:

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"prompts/list","id":4}' \
  https://your-redmine-instance.com/mcp
```

**Expected Response:**
- [ ] Returns list of 5 prompts
- [ ] Prompts include: bug_report, feature_request, status_report, sprint_summary, release_notes
- [ ] Each prompt has: name, description, arguments

### 7. Resource Templates

List resource templates:

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"resources/templates/list","id":5}' \
  https://your-redmine-instance.com/mcp
```

**Expected Response:**
- [ ] Returns 6 resource templates
- [ ] Templates include: issues, projects, wiki pages, users, time entries
- [ ] Each template has: uriTemplate, name, description, mimeType

### 8. SSE Connection

Test SSE streaming (requires a tool that supports SSE, like curl with --no-buffer):

```bash
curl -N -H "X-Redmine-API-Key: YOUR_API_KEY" \
  https://your-redmine-instance.com/mcp
```

**Expected Behavior:**
- [ ] Connection stays open
- [ ] Receives periodic heartbeat messages (default: every 30 seconds)
- [ ] Heartbeat format: `event: ping\ndata: {}\n\n`
- [ ] Connection doesn't timeout prematurely

### 9. Permission Enforcement

Test that permissions are enforced:

1. [ ] User without project access cannot see issues in that project
2. [ ] Non-admin user sees limited user profiles
3. [ ] Write operations fail when disabled in settings
4. [ ] Private notes are hidden from users without view_private_notes permission

### 10. Rate Limiting

Test rate limiting (default: 60 requests/minute):

1. [ ] Make rapid consecutive requests (>60 in 1 minute)
2. [ ] Verify rate limit error is returned
3. [ ] Error code is -32001 or appropriate HTTP 429 status
4. [ ] Rate limit resets after 1 minute

## Configuration Verification

Verify plugin settings are working:

### Plugin Settings Page

Access: **Administration > Plugins > Redmine MCP Server > Configure**

- [ ] **Enable MCP Server** - Toggle works, saves correctly
- [ ] **Enable Write Operations** - Toggle works, default is OFF
- [ ] **Rate Limit** - Accepts numeric values, default is 60
- [ ] **Request Timeout** - Accepts numeric values, default is 30
- [ ] **SSE Connection Timeout** - Accepts numeric values, default is 3600
- [ ] **Heartbeat Interval** - Accepts numeric values, default is 30
- [ ] **Default List Limit** - Accepts numeric values, default is 25
- [ ] **Maximum List Limit** - Accepts numeric values, default is 100
- [ ] Settings persist after save
- [ ] Invalid values show validation errors

### Write Protection

With write operations DISABLED:

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":6,"params":{"name":"create_issue","arguments":{"project_id":"test","subject":"Test Issue"}}}' \
  https://your-redmine-instance.com/mcp
```

**Expected Response:**
- [ ] Returns error with code -32002
- [ ] Error message: "Write operations disabled by admin..."

With write operations ENABLED:

- [ ] Same request succeeds (if user has permissions)
- [ ] Issue is created in Redmine

## MCP Client Integration

Test integration with actual MCP clients:

### Generic MCP Client

- [ ] Client configuration file accepts plugin settings
- [ ] Client successfully connects to MCP endpoint
- [ ] Client can discover and list tools
- [ ] Client can execute tools
- [ ] Client receives proper error messages

### AI Assistant Integration (if applicable)

- [ ] AI assistant recognizes Redmine MCP server
- [ ] AI can list and describe available tools
- [ ] AI can execute tools with proper parameters
- [ ] AI respects permission boundaries
- [ ] AI handles pagination correctly

## Documentation Verification

Verify all documentation is present and accurate:

- [ ] README.md is present and complete
- [ ] CHANGELOG.md is present with v1.0.0 release notes
- [ ] LICENSE file is present (MIT License)
- [ ] INSTALLATION_VERIFICATION.md (this file) is present
- [ ] docs/TOOLS.md is present with tool documentation
- [ ] docs/CONFIGURATION.md is present with server setup guides
- [ ] bin/README.md is present describing utility scripts

## Required Files Checklist

Verify all required files are present in the plugin directory:

### Core Files
- [ ] init.rb
- [ ] LICENSE
- [ ] README.md
- [ ] CHANGELOG.md
- [ ] INSTALLATION_VERIFICATION.md
- [ ] .gitignore

### Configuration
- [ ] config/routes.rb

### Controllers
- [ ] app/controllers/redmine_mcp/mcp_controller.rb

### Views
- [ ] app/views/settings/_mcp_settings.html.erb

### Library Files
- [ ] lib/redmine_mcp.rb
- [ ] lib/redmine_mcp/json_rpc.rb
- [ ] lib/redmine_mcp/sse.rb
- [ ] lib/redmine_mcp/sse_connection_tracker.rb
- [ ] lib/redmine_mcp/rate_limiter.rb
- [ ] lib/redmine_mcp/registry.rb
- [ ] lib/redmine_mcp/error_classes.rb
- [ ] lib/redmine_mcp/tools/base.rb
- [ ] lib/redmine_mcp/prompts/base.rb

### Tool Implementations (22 tools)
- [ ] lib/redmine_mcp/tools/issues/list.rb
- [ ] lib/redmine_mcp/tools/issues/get.rb
- [ ] lib/redmine_mcp/tools/issues/create.rb
- [ ] lib/redmine_mcp/tools/issues/update.rb
- [ ] lib/redmine_mcp/tools/issues/search.rb
- [ ] lib/redmine_mcp/tools/projects/list.rb
- [ ] lib/redmine_mcp/tools/projects/get.rb
- [ ] lib/redmine_mcp/tools/time_entries/list.rb
- [ ] lib/redmine_mcp/tools/time_entries/get.rb
- [ ] lib/redmine_mcp/tools/time_entries/log.rb
- [ ] lib/redmine_mcp/tools/wiki/list.rb
- [ ] lib/redmine_mcp/tools/wiki/get.rb
- [ ] lib/redmine_mcp/tools/wiki/update.rb
- [ ] lib/redmine_mcp/tools/users/list.rb
- [ ] lib/redmine_mcp/tools/users/get.rb
- [ ] lib/redmine_mcp/tools/users/get_current.rb
- [ ] lib/redmine_mcp/tools/utility/list_trackers.rb
- [ ] lib/redmine_mcp/tools/utility/list_statuses.rb
- [ ] lib/redmine_mcp/tools/utility/list_priorities.rb
- [ ] lib/redmine_mcp/tools/utility/list_activities.rb
- [ ] lib/redmine_mcp/tools/utility/list_versions.rb
- [ ] lib/redmine_mcp/tools/utility/list_categories.rb

### Prompt Implementations (5 prompts)
- [ ] lib/redmine_mcp/prompts/bug_report.rb
- [ ] lib/redmine_mcp/prompts/feature_request.rb
- [ ] lib/redmine_mcp/prompts/status_report.rb
- [ ] lib/redmine_mcp/prompts/sprint_summary.rb
- [ ] lib/redmine_mcp/prompts/release_notes.rb

### Documentation
- [ ] docs/TOOLS.md
- [ ] docs/CONFIGURATION.md

### Utilities
- [ ] bin/README.md
- [ ] bin/test_mcp_endpoint.sh
- [ ] bin/smoke_test.rb
- [ ] bin/validate_installation.rb
- [ ] bin/setup_test_data.rb

### Tests (optional but recommended)
- [ ] test/test_helper.rb
- [ ] test/unit/test_json_rpc.rb
- [ ] test/unit/test_registry.rb
- [ ] test/unit/test_rate_limiter.rb
- [ ] test/unit/tools/test_issues_tools.rb
- [ ] test/unit/tools/test_projects_tools.rb
- [ ] test/unit/tools/test_time_entries_tools.rb
- [ ] test/unit/tools/test_wiki_tools.rb
- [ ] test/unit/tools/test_users_tools.rb
- [ ] test/unit/tools/test_utility_tools.rb
- [ ] test/unit/prompts/test_prompts.rb
- [ ] test/integration/test_mcp_controller.rb

## Logs and Troubleshooting

If issues occur, check these log files:

- [ ] Redmine production log: `/path/to/redmine/log/production.log`
- [ ] Application server logs (Puma/Passenger)
- [ ] Web server logs (Nginx/Apache)
- [ ] Look for entries containing "[MCP]" prefix

Common log messages to verify:

- [ ] On startup: `[MCP] Plugin loaded: {X} tools, {Y} prompts`
- [ ] On request: `[MCP] Request received: {method}`
- [ ] On error: `[MCP] Error processing {method}: {error}`

## Performance Verification

For production deployments, verify performance:

- [ ] Response times are acceptable (<1 second for simple queries)
- [ ] Database queries are optimized (check for N+1 queries)
- [ ] Memory usage is reasonable
- [ ] SSE connections don't leak resources
- [ ] Rate limiting prevents server overload

## Security Verification

Verify security measures are in place:

- [ ] API keys are required for all non-health endpoints
- [ ] Invalid API keys are rejected
- [ ] Permission checks prevent unauthorized access
- [ ] Write protection works when enabled
- [ ] Private data is not exposed to unauthorized users
- [ ] Error messages don't leak sensitive information
- [ ] Request size limits prevent DoS attacks

## Final Checklist

Before declaring the installation complete:

- [ ] All functional tests pass
- [ ] No errors in Redmine logs
- [ ] Plugin settings are configured appropriately
- [ ] At least one MCP client can successfully connect
- [ ] Tools execute correctly and return expected data
- [ ] Permissions are properly enforced
- [ ] Documentation is accessible and understandable
- [ ] System administrator is familiar with plugin configuration

## Post-Installation Tasks

After successful installation:

1. [ ] Document the installation in your system documentation
2. [ ] Share MCP endpoint URL with authorized users
3. [ ] Provide API key generation instructions to users
4. [ ] Set up monitoring for MCP endpoint health
5. [ ] Schedule regular reviews of rate limit settings
6. [ ] Plan for future updates and maintenance

## Support and Issues

If you encounter problems:

1. Review the troubleshooting section in README.md
2. Check Redmine logs for detailed error messages
3. Verify all requirements are met
4. Test with curl commands to isolate client vs. server issues
5. Report issues to the project issue tracker

## Version Information

- **Checklist Version:** 1.0.0
- **Compatible Plugin Version:** 1.0.0
- **Last Updated:** 2025-12-07
