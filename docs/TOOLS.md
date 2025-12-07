# MCP Tools Reference

This document provides detailed documentation for all 28 tools exposed by the Redmine MCP Server plugin.

## Table of Contents

- [Issue Tools](#issue-tools)
- [Project Tools](#project-tools)
- [Time Entry Tools](#time-entry-tools)
- [Wiki Tools](#wiki-tools)
- [User Tools](#user-tools)
- [Attachment Tools](#attachment-tools)
- [Utility Tools](#utility-tools)

## General Notes

### Permissions

All tools respect Redmine's permission system. Operations will fail with a permission error if the authenticated user lacks the required permission.

### Write Protection

Tools that modify data (`create_issue`, `update_issue`, `delete_issue`, `bulk_update_issues`, `bulk_delete_issues`, `log_time`, `delete_time_entry`, `update_wiki_page`) require the "Enable Write Operations" setting to be enabled in the plugin configuration. This provides a safety mechanism to restrict AI assistants to read-only access.

### Pagination

Tools that return lists (`list_issues`, `list_projects`, etc.) include pagination metadata in the `_meta` field:

```json
{
  "_meta": {
    "total": 142,
    "limit": 25,
    "offset": 0,
    "has_more": true
  }
}
```

Use the `limit` and `offset` parameters to paginate through results.

## Issue Tools

### list_issues

List issues with optional filters.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | No | Project identifier or numeric ID |
| `status` | string | No | Filter by status: `open` (default), `closed`, or `all` |
| `assigned_to_id` | integer | No | Filter by assignee user ID |
| `tracker_id` | integer | No | Filter by tracker ID |
| `priority_id` | integer | No | Filter by priority ID |
| `limit` | integer | No | Maximum results per page (respects server `max_limit`) |
| `offset` | integer | No | Number of results to skip for pagination |
| `sort` | string | No | Sort field with optional `:desc` suffix (e.g., `created_on:desc`, `priority`) |

**Sort Fields:**

Valid values: `id`, `project`, `tracker`, `status`, `priority`, `author`, `assigned_to`, `updated_on`, `created_on`, `start_date`, `due_date`, `estimated_hours`, `done_ratio`

**Permissions:** `view_issues` (on the specified project, or any project if no filter)

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_issues",
    "arguments": {
      "project_id": "my-project",
      "status": "open",
      "sort": "priority:desc",
      "limit": 10
    }
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "[{\"id\":123,\"project\":{\"id\":1,\"name\":\"My Project\"},\"tracker\":{\"id\":1,\"name\":\"Bug\"},\"status\":{\"id\":1,\"name\":\"New\"},\"priority\":{\"id\":5,\"name\":\"Urgent\"},\"subject\":\"Critical bug\",\"assigned_to\":{\"id\":2,\"name\":\"John Doe\"},\"created_on\":\"2025-01-15T10:00:00Z\",\"updated_on\":\"2025-01-15T15:30:00Z\"}]"
    }],
    "isError": false,
    "_meta": {
      "total": 45,
      "limit": 10,
      "offset": 0,
      "has_more": true
    }
  },
  "id": 1
}
```

---

### get_issue

Retrieve detailed information about a single issue.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `issue_id` | integer | Yes | Issue ID to retrieve |
| `include` | string | No | Comma-separated list: `journals`, `attachments`, `relations`, `children`, `changesets` |

**Permissions:** `view_issues`, plus `view_private_notes` for private journals, `view_changesets` for changesets

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_issue",
    "arguments": {
      "issue_id": 123,
      "include": "journals,attachments"
    }
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"id\":123,\"project\":{\"id\":1,\"name\":\"My Project\",\"identifier\":\"my-project\"},\"tracker\":{\"id\":1,\"name\":\"Bug\"},\"status\":{\"id\":1,\"name\":\"New\",\"is_closed\":false},\"priority\":{\"id\":5,\"name\":\"Urgent\"},\"author\":{\"id\":1,\"name\":\"Admin\"},\"assigned_to\":{\"id\":2,\"name\":\"John Doe\"},\"category\":null,\"fixed_version\":null,\"subject\":\"Critical bug\",\"description\":\"Detailed description here\",\"start_date\":null,\"due_date\":\"2025-01-20\",\"done_ratio\":0,\"estimated_hours\":4.0,\"created_on\":\"2025-01-15T10:00:00Z\",\"updated_on\":\"2025-01-15T15:30:00Z\",\"closed_on\":null,\"custom_fields\":[{\"id\":1,\"name\":\"Severity\",\"value\":\"High\"}],\"journals\":[{\"id\":1,\"user\":{\"id\":2,\"name\":\"John Doe\"},\"notes\":\"Working on this issue\",\"created_on\":\"2025-01-15T12:00:00Z\",\"private_notes\":false,\"details\":[]}],\"attachments\":[{\"id\":1,\"filename\":\"screenshot.png\",\"filesize\":12345,\"content_type\":\"image/png\",\"description\":\"Error screenshot\",\"author\":{\"id\":1,\"name\":\"Admin\"},\"created_on\":\"2025-01-15T10:05:00Z\"}]}"
    }],
    "isError": false
  },
  "id": 1
}
```

---

### create_issue

Create a new issue in a project.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | Yes | Project identifier or numeric ID |
| `subject` | string | Yes | Issue subject/title |
| `description` | string | No | Issue description |
| `tracker_id` | integer | No | Tracker ID (uses project default if omitted) |
| `priority_id` | integer | No | Priority ID (uses system default if omitted) |
| `assigned_to_id` | integer | No | Assignee user ID |
| `category_id` | integer | No | Issue category ID |
| `fixed_version_id` | integer | No | Target version/milestone ID |
| `start_date` | string | No | Start date in YYYY-MM-DD format |
| `due_date` | string | No | Due date in YYYY-MM-DD format |
| `estimated_hours` | number | No | Estimated hours (decimal) |
| `done_ratio` | integer | No | Percent complete (0-100) |
| `custom_fields` | array | No | Array of custom field values: `[{"id": 1, "value": "text"}, ...]` |

**Permissions:** `add_issues`

**Requires:** Write operations enabled

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "create_issue",
    "arguments": {
      "project_id": "my-project",
      "subject": "New feature request",
      "description": "We need to add user authentication",
      "tracker_id": 2,
      "priority_id": 3,
      "assigned_to_id": 5,
      "custom_fields": [
        {"id": 1, "value": "Medium"}
      ]
    }
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"id\":456,\"project\":{\"id\":1,\"name\":\"My Project\"},\"tracker\":{\"id\":2,\"name\":\"Feature\"},\"status\":{\"id\":1,\"name\":\"New\"},\"priority\":{\"id\":3,\"name\":\"Normal\"},\"subject\":\"New feature request\",\"author\":{\"id\":1,\"name\":\"Admin\"},\"created_on\":\"2025-01-15T16:00:00Z\"}"
    }],
    "isError": false
  },
  "id": 1
}
```

---

### update_issue

Update an existing issue.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `issue_id` | integer | Yes | Issue ID to update |
| `subject` | string | No | New subject/title |
| `description` | string | No | New description |
| `status_id` | integer | No | New status ID |
| `priority_id` | integer | No | New priority ID |
| `assigned_to_id` | integer | No | New assignee user ID (null to unassign) |
| `category_id` | integer | No | New category ID |
| `fixed_version_id` | integer | No | New target version ID |
| `start_date` | string | No | New start date (YYYY-MM-DD) |
| `due_date` | string | No | New due date (YYYY-MM-DD) |
| `estimated_hours` | number | No | New estimated hours |
| `done_ratio` | integer | No | New percent complete (0-100) |
| `notes` | string | No | Journal note to document this change |
| `custom_fields` | array | No | Array of custom field values: `[{"id": 1, "value": "text"}, ...]` |

**Permissions:** `edit_issues`

**Requires:** Write operations enabled

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "update_issue",
    "arguments": {
      "issue_id": 123,
      "status_id": 3,
      "done_ratio": 50,
      "notes": "Made significant progress on this issue"
    }
  },
  "id": 1
}
```

---

### search_issues

Full-text search across issue subjects and descriptions.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `query` | string | Yes | Search query (searches subject and description) |
| `project_id` | string | No | Limit search to specific project |
| `limit` | integer | No | Maximum results per page |
| `offset` | integer | No | Number of results to skip |

**Permissions:** `view_issues`

**Note:** Uses `LIKE` queries which may be slow on large instances. Use `project_id` to narrow scope.

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "search_issues",
    "arguments": {
      "query": "authentication bug",
      "project_id": "my-project",
      "limit": 20
    }
  },
  "id": 1
}
```

---

### delete_issue

Delete an issue permanently.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `issue_id` | integer | Yes | Issue ID to delete |

**Permissions:** `delete_issues`

**Requires:** Write operations enabled

**Warning:** This action is irreversible and will also delete all related journals, attachments, time entries, and relations.

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "delete_issue",
    "arguments": {
      "issue_id": 123
    }
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"message\":\"Issue deleted successfully\",\"deleted_issue\":{\"id\":123,\"project\":{\"id\":1,\"name\":\"My Project\"},\"tracker\":{\"id\":1,\"name\":\"Bug\"},\"subject\":\"Deleted issue\"}}"
    }],
    "isError": false
  },
  "id": 1
}
```

---

### bulk_update_issues

Update multiple issues in a single operation.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `issue_ids` | array | Yes | Array of issue IDs to update (max 100) |
| `status_id` | integer | No | New status ID for all issues |
| `assigned_to_id` | integer | No | New assignee user ID (null to unassign) |
| `priority_id` | integer | No | New priority ID |
| `fixed_version_id` | integer | No | New target version ID |
| `notes` | string | No | Journal note to add to all updated issues |

**Permissions:** `edit_issues` (checked per-project)

**Requires:** Write operations enabled

**Note:** At least one field to update must be provided. Issues are processed individually, so partial failures are possible.

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "bulk_update_issues",
    "arguments": {
      "issue_ids": [1, 2, 3],
      "status_id": 5,
      "notes": "Closing sprint issues"
    }
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"updated_count\":3,\"failed_count\":0,\"updated_issues\":[{\"id\":1,\"subject\":\"Issue 1\",\"project\":\"my-project\"},...],\"failed_updates\":[]}"
    }],
    "isError": false
  },
  "id": 1
}
```

---

### bulk_delete_issues

Delete multiple issues in a single operation.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `issue_ids` | array | Yes | Array of issue IDs to delete (max 100) |

**Permissions:** `delete_issues` (checked per-project)

**Requires:** Write operations enabled

**Warning:** This action cannot be undone. Issues are processed individually, so partial failures are possible.

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "bulk_delete_issues",
    "arguments": {
      "issue_ids": [10, 11, 12]
    }
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"deleted_count\":3,\"failed_count\":0,\"deleted_issues\":[{\"id\":10,\"subject\":\"Issue 10\",\"project\":\"my-project\"},...],\"failed_deletions\":[]}"
    }],
    "isError": false
  },
  "id": 1
}
```

---

## Project Tools

### list_projects

List all visible projects.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `status` | string | No | Filter by status: `active` (default), `archived`, or `all` |
| `limit` | integer | No | Maximum results per page |
| `offset` | integer | No | Number of results to skip |

**Permissions:** None (returns only projects visible to the user)

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_projects",
    "arguments": {
      "status": "active"
    }
  },
  "id": 1
}
```

---

### get_project

Get detailed project information.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | Yes | Project identifier or numeric ID |
| `include` | string | No | Comma-separated list: `trackers`, `issue_categories`, `enabled_modules`, `time_entry_activities` |

**Permissions:** None (project must be visible to user)

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_project",
    "arguments": {
      "project_id": "my-project",
      "include": "trackers,enabled_modules"
    }
  },
  "id": 1
}
```

---

## Time Entry Tools

### list_time_entries

List time entries with optional filters.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | No | Filter by project identifier or ID |
| `issue_id` | integer | No | Filter by issue ID |
| `user_id` | integer | No | Filter by user ID |
| `from` | string | No | Start date (YYYY-MM-DD) |
| `to` | string | No | End date (YYYY-MM-DD) |
| `limit` | integer | No | Maximum results per page |
| `offset` | integer | No | Number of results to skip |

**Permissions:** `view_time_entries`

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_time_entries",
    "arguments": {
      "project_id": "my-project",
      "from": "2025-01-01",
      "to": "2025-01-31"
    }
  },
  "id": 1
}
```

---

### get_time_entry

Get detailed time entry information.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `time_entry_id` | integer | Yes | Time entry ID to retrieve |

**Permissions:** `view_time_entries`

---

### log_time

Log time to an issue or project.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `hours` | number | Yes | Hours to log (e.g., 1.5 for 1 hour 30 minutes) |
| `activity_id` | integer | Yes | Activity ID (use `list_activities` to get valid IDs) |
| `issue_id` | integer | Conditional | Issue ID to log time against (required if `project_id` not provided) |
| `project_id` | string | Conditional | Project identifier or ID (required if `issue_id` not provided) |
| `comments` | string | No | Description of work done |
| `spent_on` | string | No | Date when time was spent (YYYY-MM-DD, default: today) |
| `user_id` | integer | No | User ID to log time for (default: current user, requires `log_time_for_other_users` permission for other users) |

**Permissions:** `log_time`, plus `log_time_for_other_users` if logging for another user

**Requires:**
- Write operations enabled
- Time tracking module enabled for the project

**Note:** Exactly one of `issue_id` or `project_id` must be provided (not both).

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "log_time",
    "arguments": {
      "issue_id": 123,
      "hours": 2.5,
      "activity_id": 9,
      "comments": "Fixed authentication bug",
      "spent_on": "2025-01-15"
    }
  },
  "id": 1
}
```

---

### delete_time_entry

Delete a time entry.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `time_entry_id` | integer | Yes | Time entry ID to delete |

**Permissions:** `edit_time_entries` for any entry, or `edit_own_time_entries` for own entries

**Requires:** Write operations enabled

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "delete_time_entry",
    "arguments": {
      "time_entry_id": 456
    }
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"message\":\"Time entry deleted successfully\",\"deleted_entry\":{\"id\":456,\"project\":{\"id\":1,\"name\":\"My Project\"},\"issue\":{\"id\":123,\"subject\":\"Bug fix\"},\"user\":{\"id\":1,\"name\":\"Admin\"},\"hours\":2.5,\"spent_on\":\"2025-01-15\"}}"
    }],
    "isError": false
  },
  "id": 1
}
```

---

## Wiki Tools

### list_wiki_pages

List all wiki pages in a project.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | Yes | Project identifier or numeric ID |

**Permissions:** `view_wiki_pages`

**Requires:** Wiki module enabled for the project

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_wiki_pages",
    "arguments": {
      "project_id": "my-project"
    }
  },
  "id": 1
}
```

---

### get_wiki_page

Get wiki page content.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | Yes | Project identifier or numeric ID |
| `page_title` | string | Yes | Wiki page title |
| `version` | integer | No | Historical version number (omit for current version) |

**Permissions:** `view_wiki_pages`

**Requires:** Wiki module enabled for the project

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_wiki_page",
    "arguments": {
      "project_id": "my-project",
      "page_title": "Documentation"
    }
  },
  "id": 1
}
```

---

### update_wiki_page

Create or update a wiki page.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | Yes | Project identifier or numeric ID |
| `page_title` | string | Yes | Wiki page title (creates if it doesn't exist) |
| `content` | string | Yes | New page content (Textile or Markdown depending on project settings) |
| `comments` | string | No | Edit comment for version history |

**Permissions:** `edit_wiki_pages`

**Requires:**
- Write operations enabled
- Wiki module enabled for the project

**Note:** Creates the page if it doesn't exist (Redmine's standard behavior).

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "update_wiki_page",
    "arguments": {
      "project_id": "my-project",
      "page_title": "Installation Guide",
      "content": "h1. Installation\n\nFollow these steps...",
      "comments": "Updated installation instructions"
    }
  },
  "id": 1
}
```

---

## User Tools

### list_users

List users with tiered access.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `status` | string | No | Filter by status: `active` (default), `locked`, or `all` |
| `group_id` | integer | No | Filter by group ID |
| `limit` | integer | No | Maximum results per page |
| `offset` | integer | No | Number of results to skip |

**Permissions:**
- Admin users see all fields for all users
- Non-admin users see limited fields (id, login, firstname, lastname) for users in shared projects

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_users",
    "arguments": {
      "status": "active"
    }
  },
  "id": 1
}
```

---

### get_current_user

Get the currently authenticated user's profile.

**Parameters:** None

**Permissions:** None (always returns full profile for authenticated user)

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_current_user",
    "arguments": {}
  },
  "id": 1
}
```

---

### get_user

Get user profile information.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `user_id` | integer | Yes | User ID to retrieve |

**Permissions:**
- Admin users see full profile
- Users see their own full profile
- Non-admin users see limited fields for other users

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_user",
    "arguments": {
      "user_id": 5
    }
  },
  "id": 1
}
```

---

## Attachment Tools

### list_attachments

List attachments for a specific issue, project, or wiki page.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `issue_id` | integer | No | Filter by issue ID |
| `project_id` | string | No | Filter by project identifier or numeric ID |
| `wiki_page` | string | No | Filter by wiki page title (requires `project_id`) |

**Permissions:** Visibility permissions for the containing resource (issue, project, wiki page)

**Note:** Exactly one scope must be provided: `issue_id`, `project_id`, or `project_id` + `wiki_page`.

**Example Request (issue attachments):**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_attachments",
    "arguments": {
      "issue_id": 123
    }
  },
  "id": 1
}
```

**Example Request (project attachments):**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_attachments",
    "arguments": {
      "project_id": "my-project"
    }
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "[{\"id\":1,\"filename\":\"screenshot.png\",\"filesize\":12345,\"content_type\":\"image/png\",\"description\":\"Error screenshot\",\"author\":{\"id\":1,\"name\":\"Admin\"},\"created_on\":\"2025-01-15T10:05:00Z\",\"container_type\":\"Issue\",\"container_id\":123}]"
    }],
    "isError": false
  },
  "id": 1
}
```

---

### get_attachment

Retrieve metadata and download URL for a specific attachment.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `attachment_id` | integer | Yes | Attachment ID to retrieve |

**Permissions:** Visibility permissions for the containing resource

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_attachment",
    "arguments": {
      "attachment_id": 456
    }
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "{\"id\":456,\"filename\":\"document.pdf\",\"filesize\":98765,\"content_type\":\"application/pdf\",\"description\":\"Project specification\",\"author\":{\"id\":1,\"name\":\"Admin\"},\"created_on\":\"2025-01-15T10:05:00Z\",\"container_type\":\"Issue\",\"container_id\":123,\"download_url\":\"/attachments/download/456/document.pdf\",\"digest\":\"abc123...\"}"
    }],
    "isError": false
  },
  "id": 1
}
```

---

## Utility Tools

### list_trackers

List all issue trackers.

**Parameters:** None

**Permissions:** None

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_trackers",
    "arguments": {}
  },
  "id": 1
}
```

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "[{\"id\":1,\"name\":\"Bug\"},{\"id\":2,\"name\":\"Feature\"},{\"id\":3,\"name\":\"Support\"}]"
    }],
    "isError": false
  },
  "id": 1
}
```

---

### list_statuses

List all issue statuses.

**Parameters:** None

**Permissions:** None

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "[{\"id\":1,\"name\":\"New\",\"is_closed\":false},{\"id\":5,\"name\":\"Closed\",\"is_closed\":true}]"
    }],
    "isError": false
  },
  "id": 1
}
```

---

### list_priorities

List all issue priorities.

**Parameters:** None

**Permissions:** None

**Example Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "[{\"id\":1,\"name\":\"Low\"},{\"id\":3,\"name\":\"Normal\"},{\"id\":5,\"name\":\"Urgent\"}]"
    }],
    "isError": false
  },
  "id": 1
}
```

---

### list_activities

List time entry activities.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | No | Project identifier or ID to get project-specific activities |

**Permissions:** None

**Note:** When `project_id` is provided, returns activities available for that project (includes project-specific + inherited + system-wide). When omitted, returns only system-wide active activities.

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_activities",
    "arguments": {
      "project_id": "my-project"
    }
  },
  "id": 1
}
```

---

### list_versions

List project versions/milestones.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | Yes | Project identifier or numeric ID |
| `status` | string | No | Filter by status: `open` (default), `closed`, or `all` |

**Permissions:** None (project must be visible)

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_versions",
    "arguments": {
      "project_id": "my-project",
      "status": "open"
    }
  },
  "id": 1
}
```

---

### list_categories

List issue categories for a project.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `project_id` | string | Yes | Project identifier or numeric ID |

**Permissions:** None (project must be visible)

**Note:** Categories are project-specific, unlike trackers/statuses/priorities which are global.

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_categories",
    "arguments": {
      "project_id": "my-project"
    }
  },
  "id": 1
}
```

---

## Error Handling

All tools return MCP-compliant error responses:

### Authentication Error

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32600,
    "message": "Authentication required"
  },
  "id": null
}
```

### Permission Error

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "You don't have permission to view issues"
    }],
    "isError": true
  },
  "id": 1
}
```

### Resource Not Found

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "Issue #999 not found or not accessible"
    }],
    "isError": true
  },
  "id": 1
}
```

### Write Operations Disabled

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "Write operations are disabled by administrator"
    }],
    "isError": true
  },
  "id": 1
}
```

### Validation Error

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{
      "type": "text",
      "text": "Failed to create issue: Subject can't be blank"
    }],
    "isError": true
  },
  "id": 1
}
```

### Rate Limit Exceeded

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32000,
    "message": "Rate limit exceeded (60/min)"
  },
  "id": null
}
```
