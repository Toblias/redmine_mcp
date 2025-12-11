# Redmine MCP Server Plugin

A Redmine plugin that exposes a Model Context Protocol (MCP) server, enabling AI assistants to interact with your Redmine installation. This plugin allows AI tools to read and manage issues, projects, wiki pages, time entries, and more through a standardized protocol.

## Overview

The Redmine MCP Server plugin transforms your Redmine instance into an MCP-compatible server, allowing AI assistants to:

- Browse and search issues, projects, and wiki pages
- Create and update issues with full field support
- Log time entries against issues and projects
- Access user profiles and project metadata
- Generate structured reports using live Redmine data
- Utilize pre-built prompt templates for common workflows

All operations respect Redmine's permission system, ensuring AI assistants only access data the authenticated user can see.

## Features

- **31 Comprehensive Tools** for issue management, project navigation, time tracking, wiki editing, attachments, and metadata queries
- **5 Smart Prompts** with embedded live data for bug reports, status reports, sprint summaries, and release notes
- **6 Resource Templates** for efficient data access via URI patterns
- **HTTP + SSE Transport** for full MCP protocol compliance
- **API Key Authentication** using standard Redmine API keys
- **Permission-Based Access** - respects all Redmine permissions and visibility rules
- **Rate Limiting** to prevent runaway AI loops
- **Write Protection** - optionally restrict AI to read-only operations
- **No External Dependencies** - uses only Ruby standard library

## Requirements

- **Redmine:** 5.0 or higher
- **Ruby:** 2.7 or higher
- **MCP Client:** Any MCP-compatible client

## Installation

1. **Download the plugin:**
   ```bash
   cd /path/to/redmine/plugins
   git clone https://github.com/Toblias/redmine_mcp.git
   ```

2. **Restart Redmine:**
   ```bash
   # For Passenger
   touch /path/to/redmine/tmp/restart.txt

   # For Puma/Unicorn
   systemctl restart redmine
   ```

3. **Configure the plugin:**
   - Navigate to **Administration > Plugins > Redmine MCP Server > Configure**
   - Enable the MCP server
   - Configure rate limits and timeouts as needed
   - Optionally enable write operations (disabled by default for safety)

## Configuration

### Admin Settings

Access plugin settings at **Administration > Plugins > Redmine MCP Server > Configure**:

| Setting | Default | Description |
|---------|---------|-------------|
| **Enable MCP Server** | Enabled | Master switch for MCP endpoint |
| **Enable Write Operations** | Disabled | Allow AI to create/update issues, log time, edit wiki |
| **Rate Limit** | 60/min | Per-user request limit to prevent runaway loops |
| **Request Timeout** | 30s | Maximum tool execution time |
| **SSE Connection Timeout** | 3600s (1 hour) | Maximum SSE connection duration |
| **Heartbeat Interval** | 30s | SSE ping frequency to keep connections alive |
| **Default List Limit** | 25 | Default pagination size for list operations |
| **Maximum List Limit** | 100 | Maximum allowed pagination size |

### Security Considerations

1. **Write Operations:** Disabled by default. When enabled, AI assistants can create/modify data. Only enable for trusted users.
2. **API Keys:** Use dedicated API keys for MCP clients. Rotate keys regularly.
3. **Rate Limiting:** Prevents AI from making excessive requests. Adjust based on your server capacity.
4. **Permissions:** All operations respect Redmine permissions. Users can only access data they're authorized to see.

## MCP Endpoint

The plugin exposes a single MCP endpoint at your Redmine base URL:

### Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| **GET** | `/mcp` | SSE stream for server-initiated events |
| **POST** | `/mcp` | JSON-RPC message handling (tool execution) |
| **GET** | `/mcp/health` | Health check for load balancers (no auth required) |

### Authentication

All requests (except `/mcp/health`) require authentication via the `X-Redmine-API-Key` header:

```bash
# Health check (no authentication required)
curl https://redmine.example.com/mcp/health

# MCP requests require API key
curl -X POST \
     -H "X-Redmine-API-Key: your_api_key_here" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"ping","id":1}' \
     https://redmine.example.com/mcp
```

**Generate an API key:**
1. Log in to Redmine
2. Go to **My Account** (top right)
3. Click **Show** under "API access key" (or generate if not present)
4. Copy the key for use in your MCP client configuration

## Tools

The plugin provides 31 tools organized into categories:

### Issue Tools (8)

| Tool | Description |
|------|-------------|
| `list_issues` | List issues with filters (project, status, assignee, tracker, priority, sorting) |
| `get_issue` | Get detailed issue information with optional journals, attachments, relations |
| `create_issue` | Create a new issue with full field support including custom fields |
| `update_issue` | Update existing issue fields, add notes, change status |
| `search_issues` | Full-text search across issue subjects and descriptions |
| `delete_issue` | Delete an issue (requires delete_issues permission) |
| `bulk_update_issues` | Update multiple issues at once with common changes |
| `bulk_delete_issues` | Delete multiple issues at once (requires delete_issues permission) |

### Project Tools (5)

| Tool | Description |
|------|-------------|
| `list_projects` | List all visible projects with filtering by status |
| `get_project` | Get project details including members, versions, enabled modules |
| `create_project` | Create a new project with modules, trackers, and parent settings |
| `update_project` | Update project settings, modules, parent, and visibility |
| `delete_project` | Delete a project and all its data (admin only, irreversible) |

### Time Entry Tools (4)

| Tool | Description |
|------|-------------|
| `list_time_entries` | List time entries with filters (project, issue, user, date range) |
| `get_time_entry` | Get detailed time entry information |
| `log_time` | Log time against an issue or project |
| `delete_time_entry` | Delete a time entry (requires delete_time_entries permission) |

### Wiki Tools (3)

| Tool | Description |
|------|-------------|
| `list_wiki_pages` | List all wiki pages in a project |
| `get_wiki_page` | Get wiki page content (current or historical version) |
| `update_wiki_page` | Create or update wiki page content |

### User Tools (3)

| Tool | Description |
|------|-------------|
| `list_users` | List users (admins see all, others see users in shared projects) |
| `get_current_user` | Get currently authenticated user's profile |
| `get_user` | Get user profile (tiered response based on permissions) |

### Attachment Tools (2)

| Tool | Description |
|------|-------------|
| `list_attachments` | List attachments for an issue or project |
| `get_attachment` | Get attachment metadata and download information |

### Utility Tools (6)

| Tool | Description |
|------|-------------|
| `list_trackers` | List all issue trackers |
| `list_statuses` | List all issue statuses |
| `list_priorities` | List all issue priorities |
| `list_activities` | List time entry activities (global or project-specific) |
| `list_versions` | List project versions/milestones |
| `list_categories` | List issue categories for a project |

For detailed parameter documentation and examples, see [docs/TOOLS.md](docs/TOOLS.md).

## Prompts

The plugin includes 5 smart prompt templates that embed live Redmine data:

| Prompt | Arguments | Description |
|--------|-----------|-------------|
| `bug_report` | `project_id`, `summary` | Structured bug report template with steps to reproduce |
| `feature_request` | `project_id`, `title` | Feature request template with acceptance criteria |
| `status_report` | `project_id` (required), `period` | Project status report from real issue statistics |
| `sprint_summary` | `version_id` (required) | Sprint progress summary with completion metrics |
| `release_notes` | `version_id` (required), `format` | Generate release notes from closed issues |

**Example:** The `status_report` prompt queries your actual issue data and generates a message like:

> Generate a status report for project 'My Project' covering the last 2 weeks.
>
> Data summary:
> - Issues closed: 12
> - Issues opened: 8
> - Active issues: 45

The AI then formats this into a professional status update.

## Resource Templates

Instead of enumerating thousands of individual resources, the plugin uses URI templates that AI assistants can construct on demand:

| URI Template | Description | MIME Type |
|--------------|-------------|-----------|
| `redmine://issues/{id}` | Full issue details with journals and attachments | application/json |
| `redmine://projects/{id}` | Project information with members and versions | application/json |
| `redmine://projects/{project_id}/wiki/{title}` | Wiki page content in Textile/Markdown | text/markdown |
| `redmine://users/{id}` | User profile (permission-based fields) | application/json |
| `redmine://users/current` | Currently authenticated user's full profile | application/json |
| `redmine://time_entries/{id}` | Time entry with project and activity details | application/json |

## MCP Client Configuration

For detailed client setup instructions including Desktop, Cursor IDE, and troubleshooting, see [docs/MCP_CLIENT_SETUP.md](docs/MCP_CLIENT_SETUP.md).

### Quick Start - Generic MCP Client

Add to your MCP client configuration:

```json
{
  "mcpServers": {
    "redmine": {
      "transport": "sse",
      "url": "https://redmine.example.com/mcp",
      "headers": {
        "X-Redmine-API-Key": "your_api_key_here"
      }
    }
  }
}
```

### Quick Start - Desktop

Add to `~/Library/Application Support/Desktop/config.json` (macOS) or `%APPDATA%/Desktop/config.json` (Windows):

```json
{
  "mcpServers": {
    "redmine": {
      "transport": "sse",
      "url": "https://your-redmine.example.com/mcp",
      "headers": {
        "X-Redmine-API-Key": "your_api_key_here"
      }
    }
  }
}
```

After configuration, restart the application. The AI assistant will now be able to access your Redmine instance.

For detailed setup instructions, troubleshooting, and additional MCP clients, see [docs/MCP_CLIENT_SETUP.md](docs/MCP_CLIENT_SETUP.md).

## Server Configuration

For production deployments, you may need to configure your web server to properly handle SSE connections. See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for:

- Nginx configuration for SSE proxy
- Apache configuration
- Puma/Passenger considerations
- Rate limiting at the web server level

## Pagination

All `list_*` tools return pagination metadata to help AI assistants understand result sets:

```json
{
  "content": [{"type": "text", "text": "[... results ...]"}],
  "isError": false,
  "_meta": {
    "total": 142,
    "limit": 25,
    "offset": 0,
    "has_more": true
  }
}
```

The `_meta` field uses an underscore prefix (non-MCP extension) to provide pagination context. AI assistants can check `has_more` to determine if additional pages exist.

## Troubleshooting

### MCP endpoint returns 404

- Verify the plugin is installed in `plugins/redmine_mcp`
- Restart Redmine after installation
- Check Rails logs at `log/production.log` for routing errors

### Authentication fails

- Verify your API key is correct (check My Account > API access key)
- Ensure the key is sent in the `X-Redmine-API-Key` header
- Check that the user account is active and not locked

### SSE connection immediately closes

- Check your web server configuration (Nginx may need `X-Accel-Buffering: no`)
- Verify firewall/proxy allows long-lived connections
- Review `sse_timeout` setting (default: 3600s)
- Check Redmine logs for connection errors

### Rate limit errors

- Increase the rate limit in plugin settings (Administration > Plugins)
- Check if multiple MCP clients are using the same API key
- Review recent request patterns in Rails logs

### Write operations fail

- Verify "Enable Write Operations" is checked in plugin settings
- Confirm the user has appropriate permissions (e.g., `add_issues`, `edit_issues`)
- Check that required modules are enabled for the project (wiki, time tracking)

### Tool returns empty results

- Verify the user has permission to view the requested data
- Check project visibility settings
- Ensure the project module is enabled (wiki, time tracking, etc.)
- Review Redmine permissions for the user's role

### Performance issues

- Reduce `default_limit` and `max_limit` in settings to decrease page sizes
- Use specific filters (project_id, date ranges) to narrow queries
- Consider adding database indexes if searching is slow
- Monitor server resources during AI operations

## Development

### Running Tests

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:test NAME=redmine_mcp
```

### Adding Custom Tools

1. Create a new tool class in `lib/redmine_mcp/tools/`
2. Inherit from `RedmineMcp::Tools::Base`
3. Implement required methods: `tool_name`, `description`, `execute`
4. Register with `RedmineMcp::Registry.register_tool(YourTool)`
5. Restart Redmine

See existing tools for examples.

### Adding Custom Prompts

1. Create a new prompt class in `lib/redmine_mcp/prompts/`
2. Inherit from `RedmineMcp::Prompts::Base`
3. Implement required methods: `prompt_name`, `description`, `execute`
4. Register with `RedmineMcp::Registry.register_prompt(YourPrompt)`
5. Restart Redmine

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

This plugin is licensed under the MIT License.

```
MIT License

Copyright (c) 2025 Redmine MCP Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Support

- **Documentation:** [docs/](docs/)
- **Issues:** Report bugs and feature requests via GitHub Issues
- **Discussions:** Community support via GitHub Discussions

## Related Resources

- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)
- [Redmine Plugin Development](https://www.redmine.org/projects/redmine/wiki/Plugin_Tutorial)
- [Redmine API Documentation](https://www.redmine.org/projects/redmine/wiki/Rest_api)
