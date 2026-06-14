---
name: ado-get-workitem
description: "Fetch and display full details of an ADO work item. Use when: user asks to get, show, look up, or summarize an ADO work item; user provides a work item ID and wants to see its details, status, assignee, linked PRs, or acceptance criteria."
argument-hint: "<work-item-id>"
user-invocable: true
context: fork
---

# Get ADO Work Item Details

Fetch full details of an Azure DevOps work item and display a structured, human-readable summary — including all key fields, linked PRs, related items, and acceptance criteria.

## Permissions
- Run all expected operations autonomously — do not pause for confirmation.
- Do NOT modify any ADO data. This skill is read-only.

## MCP Tools Used

> All tools below are deferred. Load via `tool_search` before calling.

- **`mcp_ado-mcp_get_work_item`** — fetch all work item fields and relations  
  Load with: `tool_search` query `"ADO MCP get work item"`
- **`mcp_ado-mcp_get_pull_request`** — fetch linked PR title and status (optional, only if PR links exist)  
  Load with: `tool_search` query `"ADO MCP get pull request details single PR"`

> Do NOT run any local `git` commands. All data must come from ADO MCP tools.

## Steps

### Step 1 — Parse the work item ID
Extract `work_item_id` from the user's message (required). It may appear as a bare number (`974347`) or prefixed (`ADO974347`, `#974347`). Strip any prefix before calling the tool.

### Step 2 — Load MCP tool and fetch work item
1. Load `mcp_ado-mcp_get_work_item` via `tool_search`.
2. Call `mcp_ado-mcp_get_work_item` with:
   - `workItemId`: the extracted ID
   - `expand`: `"all"` (to include relations and links)

### Step 3 — Extract core fields from the response

| Field | ADO Path |
|---|---|
| Title | `System.Title` |
| Work Item Type | `System.WorkItemType` |
| State | `System.State` |
| Assigned To | `System.AssignedTo.displayName` |
| Created By | `System.CreatedBy.displayName` |
| Created Date | `System.CreatedDate` |
| Changed Date | `System.ChangedDate` |
| Area Path | `System.AreaPath` |
| Iteration Path | `System.IterationPath` |
| Priority | `Microsoft.VSTS.Common.Priority` |
| Description | `System.Description` (strip HTML tags) |
| Acceptance Criteria | `Microsoft.VSTS.Common.AcceptanceCriteria` (strip HTML tags) |
| Resolution | `Microsoft.VSTS.Common.Resolution` (if present) |
| Developer Assigned | `Custom.DeveloperAssigned.displayName` (if present) |
| QA Assigned | `Custom.QAAssigned.displayName` (if present) |
| Tags | `System.Tags` |

### Step 4 — Extract linked items from `relations`

Scan the `relations` array for:
- **Pull Requests**: entries where `rel = "ArtifactLink"` and `attributes.name = "Pull Request"`. Extract the PR ID from the URL:
  - Format: `vstfs:///Git/PullRequestId/{repoId}%2F{prId}` → PR ID is the last segment after `%2F`
  - Format: `vstfs:///CodeReview/CodeReviewId/{projectId}/{prId}` → PR ID is the final segment
- **Parent work item**: `rel = "System.LinkTypes.Hierarchy-Reverse"`
- **Child work items**: `rel = "System.LinkTypes.Hierarchy-Forward"`
- **Related work items**: `rel = "System.LinkTypes.Related"`
- **Blocked by / blocks**: `rel = "System.LinkTypes.Dependency-*"`

If PR links are found, **optionally** fetch each PR via `mcp_ado-mcp_get_pull_request` (parallel calls) to get the PR title and status. Only do this if ≤5 PRs are linked; otherwise list PR IDs only.

Extract `projectId` from the work item's `url` field:  
`https://dev.azure.com/{org}/{projectId}/_apis/wit/workItems/{id}`

### Step 5 — Display the work item summary

Output a structured markdown summary in the following format:

---

## ADO Work Item #{id} — {Title}

**Type:** {WorkItemType} | **State:** {State} | **Priority:** {Priority}  
**Sprint:** {IterationPath} | **Area:** {AreaPath}

### 👤 People
| Role | Name |
|---|---|
| Assigned To | {System.AssignedTo} |
| Developer | {DeveloperAssigned or —} |
| QA | {QAAssigned or —} |
| Created By | {CreatedBy} |

### 📅 Dates
- **Created:** {CreatedDate formatted as dd MMM yyyy}
- **Last Updated:** {ChangedDate formatted as dd MMM yyyy}

### 📝 Description
{Description — plain text, trimmed to 800 chars if very long; add "(truncated)" note if cut}

### ✅ Acceptance Criteria
{AcceptanceCriteria — plain text, or "None specified" if empty}

### 🔗 Linked Items
**Pull Requests:**
- PR #{pr_id} — {pr_title} [{status: Active|Completed|Abandoned}]  
  _(if no PRs: "None linked")_

**Related Work Items:**
- #{id} ({rel_type}) — {title if available, else just the ID}

**Tags:** {tags or "None"}

### 📋 Resolution
{Resolution content — or "Not yet resolved" if empty}

---

## Notes
- If the work item ID does not exist or the tool returns an error, report the error clearly and stop.
- Strip all HTML tags from `Description` and `AcceptanceCriteria` before displaying.
- Date format for display: `dd MMM yyyy` (e.g. `26 May 2026`).
- If a field is absent from the response, display `—` rather than leaving it blank.
- Do not infer or fabricate any field values — only display what ADO returns.
