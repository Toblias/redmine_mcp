# MCP Client Setup Guide

This guide covers how to configure various MCP clients to connect to your Redmine MCP Server.

## Table of Contents

- [Before You Begin](#before-you-begin)
- [Desktop Configuration](#desktop-configuration)
- [Cursor IDE Configuration](#cursor-ide-configuration)
- [Generic MCP Client Configuration](#generic-mcp-client-configuration)
- [Testing Your Connection](#testing-your-connection)
- [Troubleshooting](#troubleshooting)

## Before You Begin

### Prerequisites

1. **Redmine MCP Server Plugin Installed and Enabled**
   - Plugin must be installed in your Redmine instance
   - MCP server must be enabled in plugin settings
   - Verify at: **Administration > Plugins > Redmine MCP Server > Configure**

2. **API Key Generated**
   - Log in to your Redmine instance
   - Navigate to **My Account** (top right corner)
   - Under "API access key", click **Show** (or generate if not present)
   - Copy your API key for use in client configuration

3. **Server URL Known**
   - Your Redmine base URL (e.g., `https://redmine.example.com`)
   - MCP endpoint is at: `{BASE_URL}/mcp`
   - Health check endpoint: `{BASE_URL}/mcp/health`

### Quick Health Check

Before configuring any client, verify your server is accessible:

```bash
# Test health endpoint (no authentication required)
curl https://redmine.example.com/mcp/health

# Expected response:
# {"status":"healthy","timestamp":"2025-12-07T10:00:00Z"}
```

If the health check fails, review your [server configuration](CONFIGURATION.md) before proceeding.

## Desktop Configuration

Desktop is an interface that supports MCP natively.

### Configuration File Location

The configuration file is located at:

- **macOS:** `~/Library/Application Support/Desktop/config.json`
- **Windows:** `%APPDATA%\Desktop\config.json`
- **Linux:** `~/.config/Desktop/config.json`

### Configuration Format

Add the following to your `config.json` file under the `mcpServers` section:

```json
{
  "mcpServers": {
    "redmine": {
      "url": "https://redmine.example.com/mcp",
      "transport": "sse",
      "headers": {
        "X-Redmine-API-Key": "your_api_key_here"
      },
      "settings": {
        "timeout": 30000,
        "reconnect": true,
        "reconnectInterval": 5000
      }
    }
  }
}
```

### Configuration Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `url` | `https://redmine.example.com/mcp` | Your Redmine MCP endpoint URL |
| `transport` | `sse` | Transport protocol (Server-Sent Events) |
| `headers.X-Redmine-API-Key` | `your_api_key_here` | Your Redmine API key |
| `settings.timeout` | `30000` | Request timeout in milliseconds (30 seconds) |
| `settings.reconnect` | `true` | Auto-reconnect on connection loss |
| `settings.reconnectInterval` | `5000` | Reconnect delay in milliseconds (5 seconds) |

### Step-by-Step Setup

1. **Locate Configuration File**
   ```bash
   # macOS/Linux
   nano ~/Library/Application\ Support/Desktop/config.json

   # Or use any text editor
   ```

2. **Edit Configuration**
   - If the file doesn't exist, create it with the structure shown above
   - If it exists, add the `redmine` entry under `mcpServers`
   - Replace `https://redmine.example.com` with your Redmine URL
   - Replace `your_api_key_here` with your API key

3. **Save and Restart Desktop**
   - Save the configuration file
   - Quit Desktop completely
   - Restart Desktop

4. **Verify Connection**
   - Open Desktop
   - Look for "Redmine" in the available MCP servers list
   - Try asking a question like: "List my open issues in Redmine"

### Multiple Redmine Instances

You can configure multiple Redmine servers:

```json
{
  "mcpServers": {
    "redmine-production": {
      "url": "https://redmine.example.com/mcp",
      "transport": "sse",
      "headers": {
        "X-Redmine-API-Key": "production_api_key"
      }
    },
    "redmine-staging": {
      "url": "https://staging.redmine.example.com/mcp",
      "transport": "sse",
      "headers": {
        "X-Redmine-API-Key": "staging_api_key"
      }
    }
  }
}
```

### Desktop-Specific Troubleshooting

**Issue:** Desktop doesn't show Redmine MCP server

**Solutions:**
1. Check JSON syntax is valid (use a JSON validator)
2. Ensure Desktop was fully restarted after configuration changes
3. Check Desktop logs:
   - macOS: `~/Library/Logs/Desktop/`
   - Windows: `%APPDATA%\Desktop\logs\`
   - Linux: `~/.config/Desktop/logs/`

**Issue:** "Connection failed" error

**Solutions:**
1. Verify health endpoint works: `curl https://redmine.example.com/mcp/health`
2. Check API key is correct (try it with curl first)
3. Ensure HTTPS certificate is valid (Desktop may reject self-signed certificates)
4. Review network/firewall settings

## Cursor IDE Configuration

Cursor IDE has built-in MCP support.

### Configuration File Location

Cursor's MCP configuration is in:

- **macOS:** `~/Library/Application Support/Cursor/User/globalStorage/settings.json`
- **Windows:** `%APPDATA%\Cursor\User\globalStorage\settings.json`
- **Linux:** `~/.config/Cursor/User/globalStorage/settings.json`

### Configuration Format

Add the following to your Cursor settings:

```json
{
  "mcp.servers": {
    "redmine": {
      "url": "https://redmine.example.com/mcp",
      "transport": "sse",
      "headers": {
        "X-Redmine-API-Key": "your_api_key_here"
      }
    }
  }
}
```

### Step-by-Step Setup

1. **Open Cursor Settings**
   - Press `Cmd+,` (macOS) or `Ctrl+,` (Windows/Linux)
   - Or go to **File > Preferences > Settings**

2. **Open Settings JSON**
   - Click the file icon in the top right (Open Settings JSON)
   - Or press `Cmd+Shift+P` / `Ctrl+Shift+P` and search for "Preferences: Open User Settings (JSON)"

3. **Add MCP Configuration**
   ```json
   {
     "mcp.servers": {
       "redmine": {
         "url": "https://redmine.example.com/mcp",
         "transport": "sse",
         "headers": {
           "X-Redmine-API-Key": "your_api_key_here"
         }
       }
     }
   }
   ```

4. **Save and Reload**
   - Save the settings file (`Cmd+S` / `Ctrl+S`)
   - Reload Cursor: `Cmd+Shift+P` / `Ctrl+Shift+P` → "Developer: Reload Window"

5. **Verify Connection**
   - Open the AI chat in Cursor
   - The Redmine MCP tools should be available
   - Try: "Show me my open issues from Redmine"

### Using MCP Tools in Cursor

Once connected, you can use Redmine tools in several ways:

1. **Natural Language Queries**
   ```
   "What are my high priority issues in the mobile-app project?"
   "Create a bug report for login failure"
   "Show me time entries for this week"
   ```

2. **Inline Code Assistance**
   - Select code and ask: "Create a Redmine issue for this bug"
   - Get project context while coding

3. **Workspace Integration**
   - Reference Redmine issues in comments
   - Generate status reports from Redmine data

### Cursor-Specific Troubleshooting

**Issue:** MCP tools not appearing in Cursor

**Solutions:**
1. Verify settings.json syntax (JSON must be valid)
2. Reload Cursor window completely
3. Check Cursor's developer console:
   - `Cmd+Shift+P` / `Ctrl+Shift+P` → "Developer: Toggle Developer Tools"
   - Look for MCP-related errors in console

**Issue:** "MCP server not responding"

**Solutions:**
1. Test connection with curl (see [Testing Your Connection](#testing-your-connection))
2. Check API key permissions in Redmine
3. Verify Cursor can reach your Redmine server (corporate firewall may block)

## Generic MCP Client Configuration

For any MCP-compatible client not covered above.

### HTTP Endpoint Details

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/mcp` | GET | SSE stream for server events | Required |
| `/mcp` | POST | JSON-RPC tool execution | Required |
| `/mcp/health` | GET | Health check | Not required |

### Authentication

All requests (except `/mcp/health`) require the `X-Redmine-API-Key` header:

```http
X-Redmine-API-Key: your_api_key_here
```

### SSE Connection (GET /mcp)

Establish a Server-Sent Events connection for receiving server-initiated messages:

```bash
curl -N -H "X-Redmine-API-Key: your_api_key_here" \
     https://redmine.example.com/mcp
```

**Expected Response:**
```
data: {"jsonrpc":"2.0","method":"ping"}

data: {"jsonrpc":"2.0","method":"ping"}
```

You should receive ping events every 30 seconds (default heartbeat interval).

**Connection Parameters:**
- **Timeout:** Connection can remain open for up to 1 hour (default `sse_timeout`)
- **Heartbeat:** Ping events sent every 30 seconds (default `heartbeat_interval`)
- **Auto-reconnect:** Client should reconnect on disconnect

### JSON-RPC Tool Calls (POST /mcp)

Execute MCP tools via JSON-RPC:

```bash
curl -X POST \
     -H "X-Redmine-API-Key: your_api_key_here" \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "method": "tools/call",
       "params": {
         "name": "list_issues",
         "arguments": {
           "project_id": "my-project",
           "status": "open",
           "limit": 10
         }
       },
       "id": 1
     }' \
     https://redmine.example.com/mcp
```

**Expected Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "[{\"id\":123,\"subject\":\"Bug in login\",...}]"
    }],
    "isError": false
  },
  "id": 1
}
```

### Available Methods

| Method | Purpose |
|--------|---------|
| `initialize` | Initialize MCP session (optional) |
| `ping` | Keepalive ping |
| `tools/list` | List all available tools |
| `tools/call` | Execute a specific tool |
| `prompts/list` | List available prompts |
| `prompts/get` | Get prompt template with live data |
| `resources/list` | List available resource templates |
| `resources/read` | Read a resource by URI |

### Example: List Available Tools

```bash
curl -X POST \
     -H "X-Redmine-API-Key: your_api_key_here" \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "method": "tools/list",
       "params": {},
       "id": 1
     }' \
     https://redmine.example.com/mcp
```

### Example: Get Issue Details

```bash
curl -X POST \
     -H "X-Redmine-API-Key: your_api_key_here" \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "method": "tools/call",
       "params": {
         "name": "get_issue",
         "arguments": {
           "id": 123,
           "include": ["journals", "attachments"]
         }
       },
       "id": 1
     }' \
     https://redmine.example.com/mcp
```

### Example: Create Issue (Write Operation)

```bash
curl -X POST \
     -H "X-Redmine-API-Key: your_api_key_here" \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "method": "tools/call",
       "params": {
         "name": "create_issue",
         "arguments": {
           "project_id": "my-project",
           "subject": "Test issue from MCP",
           "description": "Created via MCP API",
           "tracker_id": 1,
           "priority_id": 2
         }
       },
       "id": 1
     }' \
     https://redmine.example.com/mcp
```

**Note:** Write operations require "Enable Write Operations" to be enabled in plugin settings.

### Rate Limiting

The server implements rate limiting (default: 60 requests/minute per user). Respect rate limits:

**Rate Limit Headers:**
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 59
X-RateLimit-Reset: 1609459260
```

**Rate Limit Exceeded Response:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32000,
    "message": "Rate limit exceeded. Try again in 30 seconds."
  },
  "id": 1
}
```

## Testing Your Connection

### 1. Health Check (No Auth)

```bash
curl https://redmine.example.com/mcp/health
```

**Expected:** `{"status":"healthy","timestamp":"..."}`

**If this fails:**
- Server is not running or not accessible
- Check web server configuration
- Verify URL is correct

### 2. Authenticated Ping

```bash
curl -X POST \
     -H "X-Redmine-API-Key: your_api_key_here" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"ping","id":1}' \
     https://redmine.example.com/mcp
```

**Expected:** `{"jsonrpc":"2.0","result":{},"id":1}`

**If this fails:**
- API key is invalid or missing
- Authentication is not properly configured
- User account is locked or inactive

### 3. List Tools

```bash
curl -X POST \
     -H "X-Redmine-API-Key: your_api_key_here" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}' \
     https://redmine.example.com/mcp
```

**Expected:** JSON response with array of 28 tools

**If this fails:**
- MCP server may not be enabled in plugin settings
- Plugin may not be properly installed

### 4. SSE Connection Test

```bash
curl -N -H "X-Redmine-API-Key: your_api_key_here" \
     https://redmine.example.com/mcp
```

**Expected:** Continuous stream of ping events every 30 seconds

**If connection closes immediately:**
- Web server buffering may be enabled (see [CONFIGURATION.md](CONFIGURATION.md))
- Proxy timeout may be too short
- Check Nginx/Apache SSE configuration

### 5. Basic Tool Call

```bash
curl -X POST \
     -H "X-Redmine-API-Key: your_api_key_here" \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "method": "tools/call",
       "params": {
         "name": "list_projects",
         "arguments": {}
       },
       "id": 1
     }' \
     https://redmine.example.com/mcp
```

**Expected:** JSON array of projects visible to authenticated user

## Troubleshooting

### Common Connection Issues

#### Issue: "Connection refused" or "Cannot connect to server"

**Symptoms:**
- Client can't establish connection to MCP endpoint
- Timeout errors

**Causes:**
- Redmine server not running
- Incorrect URL in client configuration
- Firewall blocking access
- Web server not configured to proxy `/mcp` endpoint

**Solutions:**

1. **Verify server is running:**
   ```bash
   curl https://redmine.example.com/mcp/health
   ```

2. **Check URL format:**
   - Should be: `https://redmine.example.com/mcp`
   - Not: `https://redmine.example.com/mcp/` (no trailing slash)
   - Not: `https://redmine.example.com` (missing `/mcp` path)

3. **Test from same network as client:**
   ```bash
   # From client machine
   ping redmine.example.com
   curl https://redmine.example.com
   ```

4. **Review web server logs:**
   ```bash
   # Nginx
   tail -f /var/log/nginx/error.log

   # Apache
   tail -f /var/log/apache2/error.log
   ```

#### Issue: "Authentication required" or "Invalid API key"

**Symptoms:**
- Health check works, but authenticated requests fail
- 401 Unauthorized errors

**Causes:**
- API key is incorrect, expired, or not set
- User account is locked or inactive
- API key header not sent or misspelled

**Solutions:**

1. **Verify API key is correct:**
   - Log in to Redmine
   - Go to **My Account**
   - Check API key matches configuration

2. **Test API key directly:**
   ```bash
   curl -H "X-Redmine-API-Key: your_key" \
        https://redmine.example.com/users/current.json
   ```
   Should return your user data.

3. **Check header name (case-sensitive):**
   - Correct: `X-Redmine-API-Key`
   - Wrong: `X-Redmine-Api-Key`, `x-redmine-api-key`

4. **Regenerate API key if needed:**
   - **My Account** > Reset API access key

#### Issue: "Rate limit exceeded"

**Symptoms:**
- Requests fail after working initially
- Error: "Rate limit exceeded. Try again in X seconds."

**Causes:**
- Too many requests in short time period
- AI assistant making requests in a loop

**Solutions:**

1. **Wait for rate limit to reset:**
   - Default: 60 requests per minute
   - Check `X-RateLimit-Reset` header for exact time

2. **Adjust rate limit in plugin settings:**
   - **Administration > Plugins > Redmine MCP Server > Configure**
   - Increase "Rate Limit" if your server can handle more load

3. **Optimize client behavior:**
   - Reduce frequency of polling requests
   - Batch related queries when possible

#### Issue: SSE connection closes immediately

**Symptoms:**
- SSE stream disconnects after a few seconds
- No ping events received

**Causes:**
- Web server buffering enabled (most common)
- Proxy timeout too short
- Load balancer closing idle connections

**Solutions:**

1. **Check web server SSE configuration:**
   - Review [CONFIGURATION.md](CONFIGURATION.md) for Nginx/Apache SSE settings
   - Ensure `proxy_buffering off` (Nginx) or equivalent

2. **Verify timeout settings:**
   - Nginx: `proxy_read_timeout` should be ≥ 3600s
   - Apache: `ProxyTimeout` should be ≥ 3600s
   - Plugin setting: "SSE Connection Timeout" (default 3600s)

3. **Test direct connection (bypass proxy):**
   ```bash
   # If using Puma on port 3000
   curl -N -H "X-Redmine-API-Key: your_key" \
        http://localhost:3000/mcp
   ```
   If this works but proxied connection doesn't, issue is in web server config.

4. **Check load balancer settings:**
   - AWS ALB: Increase idle timeout to 3600s
   - See [CONFIGURATION.md](CONFIGURATION.md) for details

#### Issue: "Tool not found" or "Method not supported"

**Symptoms:**
- Client reports tool doesn't exist
- Specific tools fail while others work

**Causes:**
- Client cache is stale
- Plugin not fully initialized
- Typo in tool name

**Solutions:**

1. **Verify tool exists:**
   ```bash
   curl -X POST \
        -H "X-Redmine-API-Key: your_key" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}' \
        https://redmine.example.com/mcp
   ```
   Check if the tool appears in the list.

2. **Restart client:**
   - Desktop: Quit and restart completely
   - Cursor: Reload window

3. **Restart Redmine:**
   ```bash
   # Passenger
   touch /path/to/redmine/tmp/restart.txt

   # Puma
   systemctl restart redmine
   ```

4. **Check tool name spelling:**
   - Tool names are case-sensitive
   - Correct: `list_issues`, `get_project`
   - Wrong: `listIssues`, `getProject`

#### Issue: "Permission denied" for write operations

**Symptoms:**
- Read operations work (list_issues, get_issue)
- Write operations fail (create_issue, update_issue, log_time)

**Causes:**
- "Enable Write Operations" disabled in plugin settings (most common)
- User lacks required Redmine permission
- Project permissions restrict operation

**Solutions:**

1. **Enable write operations:**
   - **Administration > Plugins > Redmine MCP Server > Configure**
   - Enable "Enable Write Operations"
   - Note: Only enable for trusted users/environments

2. **Check Redmine permissions:**
   - **Administration > Roles and permissions**
   - Ensure user's role has required permissions:
     - Create issues: `add_issues`
     - Update issues: `edit_issues`
     - Log time: `log_time`
     - Edit wiki: `edit_wiki_pages`

3. **Verify project membership:**
   ```bash
   curl -H "X-Redmine-API-Key: your_key" \
        https://redmine.example.com/projects/my-project/memberships.json
   ```
   User must be a member of the project with appropriate role.

### Enable Debug Logging

For persistent issues, enable detailed logging:

1. **Redmine Logs:**
   ```bash
   tail -f log/production.log
   ```
   Look for lines containing `[MCP]` or `RedmineMcp`

2. **Increase log level temporarily:**
   Edit `config/additional_environment.rb`:
   ```ruby
   config.log_level = :debug
   ```
   Restart Redmine, reproduce issue, then restore to `:info`

3. **Client Logs:**
   - Desktop: Check logs in Desktop's log directory
   - Cursor: Open Developer Tools console
   - Generic client: Enable verbose/debug mode if available

4. **Web Server Logs:**
   ```bash
   # Nginx access log
   tail -f /var/log/nginx/access.log | grep /mcp

   # Nginx error log
   tail -f /var/log/nginx/error.log
   ```

### Getting Help

If troubleshooting doesn't resolve your issue:

1. **Collect diagnostic information:**
   - Redmine version: `cat VERSION` in Redmine root
   - Plugin version: Check `init.rb` in plugin directory
   - Ruby version: `ruby -v`
   - Web server: Nginx/Apache version
   - Client: Type and version
   - Exact error message from logs

2. **Check existing issues:**
   - Review plugin's issue tracker
   - Search for similar problems

3. **Create detailed bug report:**
   - Include all diagnostic information
   - Provide minimal reproduction steps
   - Attach relevant log excerpts (redact sensitive data)

## Best Practices

### Security

1. **Use HTTPS:** Always use HTTPS in production to protect API keys
2. **Dedicated API Keys:** Create dedicated API keys for MCP clients (not personal admin keys)
3. **Rotate Keys Regularly:** Refresh API keys every 90 days
4. **Read-Only by Default:** Only enable write operations when necessary
5. **Monitor Usage:** Review Redmine logs for unusual activity

### Performance

1. **Limit Pagination:** Use reasonable limits (25-50) for list operations
2. **Cache When Possible:** Clients should cache frequently accessed data
3. **Respect Rate Limits:** Implement backoff when approaching rate limit
4. **Use Filters:** Be specific with queries to reduce server load

### Reliability

1. **Auto-Reconnect:** Configure clients to reconnect on SSE disconnect
2. **Health Checks:** Periodically verify connection health
3. **Graceful Degradation:** Handle temporary service unavailability
4. **Timeout Handling:** Implement appropriate timeout logic in client

## Additional Resources

- [MCP Tools Reference](TOOLS.md) - Detailed documentation of all 28 tools
- [Server Configuration Guide](CONFIGURATION.md) - Web server setup for production
- [MCP Specification](https://spec.modelcontextprotocol.io/) - Official MCP protocol documentation
- [Redmine API Documentation](https://www.redmine.org/projects/redmine/wiki/Rest_api) - Underlying REST API reference
