# Changelog

All notable changes to the Redmine MCP Server plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-07

### Added

#### Core Infrastructure
- HTTP + SSE transport implementation with full MCP protocol compliance
- JSON-RPC 2.0 message handling with batch request support
- Server-Sent Events (SSE) streaming with configurable heartbeat
- API key authentication using standard Redmine `X-Redmine-API-Key` header
- Rate limiting with token bucket algorithm (configurable per-user limit)
- Request timeout protection (configurable, default 30s)
- Write operations toggle for safety (disabled by default)
- Health check endpoint (`/mcp/health`) for load balancers
- Comprehensive error handling with MCP-compliant error responses
- Zero external dependencies (uses only Ruby standard library)

#### Issue Tools (8)
- `list_issues` - List issues with filters (project, status, assignee, tracker, priority, sort)
- `get_issue` - Get detailed issue with optional includes (journals, attachments, relations, children, changesets)
- `create_issue` - Create new issues with full field support including custom fields
- `update_issue` - Update existing issues with optimistic locking support
- `search_issues` - Full-text search across issue subjects and descriptions
- `delete_issue` - Delete an issue (requires delete_issues permission)
- `bulk_update_issues` - Update multiple issues at once with common changes
- `bulk_delete_issues` - Delete multiple issues at once (requires delete_issues permission)

#### Project Tools (2)
- `list_projects` - List all visible projects with status filter
- `get_project` - Get project details with optional includes (trackers, categories, modules, activities)

#### Time Entry Tools (4)
- `list_time_entries` - List time entries with filters (project, issue, user, date range)
- `get_time_entry` - Get detailed time entry information
- `log_time` - Log time to issues or projects with activity tracking
- `delete_time_entry` - Delete a time entry (requires delete_time_entries permission)

#### Wiki Tools (3)
- `list_wiki_pages` - List all wiki pages in a project
- `get_wiki_page` - Get wiki page content (current or historical version)
- `update_wiki_page` - Create or update wiki pages with version history

#### User Tools (3)
- `list_users` - List users with tiered access (admin vs. non-admin)
- `get_current_user` - Get authenticated user's full profile
- `get_user` - Get user profile with permission-based field filtering

#### Attachment Tools (2)
- `list_attachments` - List attachments for an issue or project
- `get_attachment` - Get attachment metadata and download information

#### Utility Tools (6)
- `list_trackers` - List all issue trackers
- `list_statuses` - List all issue statuses with closed flag
- `list_priorities` - List all issue priorities
- `list_activities` - List time entry activities (global or project-specific)
- `list_versions` - List project versions/milestones with status filter
- `list_categories` - List issue categories for a project

#### Prompts (5)
- `bug_report` - Structured bug report template with steps to reproduce
- `feature_request` - Feature request template with acceptance criteria
- `status_report` - Project status report with live issue statistics
- `sprint_summary` - Sprint progress summary with completion metrics
- `release_notes` - Generate release notes from closed issues in a version

#### Resource Templates (6)
- `redmine://issues/{id}` - Full issue details with journals and attachments
- `redmine://projects/{id}` - Project information with members and versions
- `redmine://projects/{project_id}/wiki/{title}` - Wiki page content
- `redmine://users/{id}` - User profile with permission-based fields
- `redmine://users/current` - Current user's full profile
- `redmine://time_entries/{id}` - Time entry with project and activity details

#### Admin Features
- Plugin settings page with comprehensive configuration options
- Enable/disable MCP server master switch
- Write operations safety toggle
- Rate limiting configuration (requests per minute)
- Timeout configuration (request timeout, SSE timeout, heartbeat interval)
- Pagination defaults (default limit, max limit)
- Real-time settings validation

#### Security Features
- Permission-based access control (respects all Redmine permissions)
- Module enablement checks (wiki, time tracking)
- Visibility scope enforcement (projects, issues, users, wiki pages)
- Private note protection (requires `view_private_notes` permission)
- Tiered user data access (admin vs. non-admin)
- Write protection flag for read-only AI access
- Request size limiting (1MB max payload)
- Optimistic locking for concurrent update prevention

#### Developer Features
- Tool registry system with auto-discovery
- Prompt registry system with auto-discovery
- Abstract base classes for tools and prompts (`Tools::Base`, `Prompts::Base`)
- Pagination helper with automatic metadata generation
- Permission check helpers
- Module enablement helpers
- Error handling framework with custom exceptions
- Comprehensive test suite
- Inline documentation and code comments

#### Documentation
- Complete README with installation, configuration, and usage instructions
- Detailed TOOLS.md with full parameter documentation and examples
- CONFIGURATION.md with web server setup guides (Nginx, Apache)
- CHANGELOG.md (this file)
- MIT License

### Technical Details

#### Architecture
- Namespaced under `RedmineMcp::` to avoid gem name collisions
- Lean V1 architecture with no database models (stateless design)
- SSE implemented with custom `RedmineMcp::SSE` class (Rails doesn't provide one)
- JSON-RPC handler with inline resource dispatch
- Thread-safe registry with freeze-after-load pattern
- Compatible with Redmine 5.0+ and Ruby 2.7+

#### Performance
- Eager loading with `includes()` to prevent N+1 queries
- Batch visibility checks for related issues
- Pagination metadata with `has_more` flag for efficient iteration
- Configurable connection and request timeouts
- Memory-bounded request payloads (1MB limit)

#### Standards Compliance
- [MCP Specification](https://spec.modelcontextprotocol.io/) compliance
- JSON-RPC 2.0 protocol
- SSE (Server-Sent Events) specification
- RESTful API design principles
- Semantic Versioning

### Known Limitations

- `search_issues` uses `LIKE` queries which may be slow on large instances (>50k issues)
  - **Mitigation:** Use `project_id` parameter to narrow scope
  - **Future:** Consider integration with Redmine search infrastructure or Elasticsearch
- SSE is heartbeat-only in V1 (no server-initiated sampling)
  - **Future:** V2 may add sampling support for proactive notifications
- Filter parameters accept single values only (not pipe-separated multi-value like native Redmine API)
  - **Mitigation:** Make multiple requests or use broader filters
- Ruby `Timeout` module has thread-safety caveats
  - **Risk:** Low for V1 due to database transactions
  - **Future:** Consider async execution with explicit cancellation

### Requirements

- **Redmine:** 5.0 or higher
- **Ruby:** 2.7 or higher
- **Application Server:** Puma or Passenger (Unicorn not supported due to SSE requirements)
- **Web Server:** Nginx or Apache with proper SSE configuration (see CONFIGURATION.md)

### Installation

See [README.md](README.md) for installation instructions.

### Upgrade Notes

First release - no upgrade considerations.

---

## [Unreleased]

### Planned Features (V2)

- Server-initiated sampling via SSE for proactive updates
- Integration with Redmine search infrastructure for faster full-text search
- Async tool execution with explicit cancellation (safer than Ruby `Timeout`)
- Multi-value filter support (e.g., `status_id=1|2|3`)
- File attachment upload support for `create_issue` and `update_issue`
- Custom field type support (file, user, version) in issue creation
- Watchers management (add/remove watchers on issues)
- Issue cloning tool
- Bulk issue operations
- Gantt chart data export
- Calendar data export
- Forum/message board tools (if forum module enabled)
- Document repository tools (if documents module enabled)
- Performance metrics and analytics
- WebSocket transport option (in addition to SSE)
- GraphQL query support as alternative to JSON-RPC

### Planned Improvements (V2)

- Database query optimization with materialized views
- Connection pooling improvements for high-concurrency scenarios
- Enhanced rate limiting with sliding window algorithm
- Request caching with ETags for unchanged data
- Compression support (gzip, brotli) for large responses
- Internationalization (i18n) support for error messages
- Plugin conflict detection and compatibility warnings
- Migration guides from V1 to V2

---

## Version History

- **1.0.0** (2025-12-07) - Initial release with 28 tools, 5 prompts, and full MCP compliance

---

## Links

- [GitHub Repository](https://github.com/redmine/redmine_mcp)
- [Issue Tracker](https://github.com/redmine/redmine_mcp/issues)
- [Documentation](https://github.com/redmine/redmine_mcp/tree/main/docs)
- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [Redmine Plugin API](https://www.redmine.org/projects/redmine/wiki/Plugin_Tutorial)
