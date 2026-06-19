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

- **`mcp_azure-devops-_get_work_item`** — fetch all work item fields and relations  
  Load with: `tool_search` query `"ADO MCP get work item"`
- **`mcp_azure-devops-_get_pull_request`** — fetch linked PR title, status, reviewers, and description  
  Load with: `tool_search` query `"ADO MCP get pull request details single PR"`
- **`mcp_azure-devops-_get_pull_request_comments`** — fetch all PR thread comments  
  Load with: `tool_search` query `"ADO MCP get pull request comments"`
- **`mcp_azure-devops-_get_pull_request_changes`** — fetch changed files list for a PR  
  Load with: `tool_search` query `"ADO MCP get pull request changes"`
- **`mcp_secure-filesy_write_file`** — write output file to disk  
  Load with: `tool_search` query `"secure filesystem write file"`

> Do NOT run any local `git` commands. All data must come from ADO MCP tools.

## Steps

### Step 1 — Parse the work item ID
Extract `work_item_id` from the user's message (required). It may appear as a bare number (`974347`) or prefixed (`ADO974347`, `#974347`). Strip any prefix before calling the tool.

### Step 2 — Load MCP tools and fetch work item data
1. Load all required MCP tools via `tool_search` (see MCP Tools section above).
2. Call `mcp_azure-devops-_get_work_item` with:
   - `workItemId`: the extracted ID
   - `expand`: `"all"` (to include relations and links)
3. After receiving the work item response, extract `projectId` from the `url` field:
   `https://dev.azure.com/{org}/{projectId}/_apis/wit/workItems/{id}`

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
- **Attachments**: entries where `rel = "AttachedFile"`. Extract `attributes.name` (filename) and `url`.
- **Hyperlinks / external links**: entries where `rel = "Hyperlink"`. Extract `url` and `attributes.comment`.
- **Parent work item**: `rel = "System.LinkTypes.Hierarchy-Reverse"`
- **Child work items**: `rel = "System.LinkTypes.Hierarchy-Forward"`
- **Related work items**: `rel = "System.LinkTypes.Related"`
- **Blocked by / blocks**: `rel = "System.LinkTypes.Dependency-*"`

If PR links are found, fetch each PR via `mcp_azure-devops-_get_pull_request` (parallel calls if ≤5 PRs) to get:
- PR title, status (Active/Completed/Abandoned), target branch, created date
- Reviewers and their vote status
- Description (first 300 chars)

For each fetched PR, also call `mcp_azure-devops-_get_pull_request_comments` in parallel to retrieve review thread comments (active threads only; skip system/resolved threads).

If >5 PRs are linked, list PR IDs only without fetching details.

### Step 5 — Save all responses to disk

Save all collected API responses as a single Markdown file with JSON code blocks:

- **Path:** `/home/laksyalamat/projects/git/ai-forge/outcomes/ado-get-workitem/ADO{id}.md`
- **Content format:**
  ````
  # ADO Work Item {id} — Raw API Responses

  ## Work Item

  ```json
  { ...work item response... }
  ```

  ## Pull Request {prId} (if fetched)

  ```json
  { ...PR response... }
  ```

  ## PR {prId} Comments (if fetched)

  ```json
  { ...comments response... }
  ```
  ````
- Use `mcp_secure-filesy_write_file` to write the file.
- If the file already exists, overwrite it.
- After writing, confirm the save path in the output summary.

### Step 6 — Display the work item summary

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

### 🔗 Pull Requests
| PR # | Title | Status | Branch | Created |
|---|---|---|---|---|
| #{pr_id} | {pr_title} | {Active/Completed/Abandoned} | {targetBranch} | {createdDate dd MMM yyyy} |
_(if no PRs: "None linked")_

**Reviewers** (per PR):
- {reviewer name}: {vote: Approved / Approved with suggestions / Waiting for author / Rejected / No vote}

**PR Description:** {first 300 chars, or "—" if empty}

**PR Comments** (active threads only):
- [{author}] {comment text}

### 🗂 Related Work Items
| ID | Type | Relationship |
|---|---|---|
| #{id} | {type if available} | {rel_type: Parent / Child / Related / Blocked By / Blocks} |

### 📎 Attachments
- [{filename}]({url}) _(if none: "None")_

### 🌐 Hyperlinks / External Links
- [{comment or url}]({url}) _(if none: "None")_

**Tags:** {tags or "None"}

### 📋 Resolution
{Resolution content — plain text, strip HTML — or "Not yet resolved" if empty}

---

## Notes
- Save all raw API responses to `/home/laksyalamat/projects/git/ai-forge/outcomes/ado-get-workitem/ADO{id}.md` as fenced `json` code blocks before displaying the summary. If the write fails, log a warning but still display the summary.
- If the work item ID does not exist or the tool returns an error, report the error clearly and stop.
- Strip all HTML tags from `Description`, `AcceptanceCriteria`, and `Resolution` before displaying.
- Date format for display: `dd MMM yyyy` (e.g. `26 May 2026`).
- For PR comments, only include active (non-resolved) threads. Skip system-generated comments (e.g. vote changes, policy events).
- If a PR has no active comment threads, display "No active review comments".
- If a field is absent from the response, display `—` rather than leaving it blank.
- Do not infer or fabricate any field values — only display what ADO returns.
