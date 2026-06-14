---
name: ado-resolution-full
description: "Generate a detailed resolution markdown file (root cause, fix details, changes) for an ADO work item. Use when: user asks to generate a resolution write-up, create a full resolution doc, or get a detailed resolution for an ADO item. Selects Bug Fix, Enhancement, or Support template based on work item type. Saves output as a markdown file in outcomes/ado/resolutions/."
argument-hint: "<work-item-id> [--auto]"
user-invocable: true
context: fork
---

# Generate Full Resolution Document for an ADO Work Item

Generate a detailed resolution markdown file for an ADO work item. Saves the result to `outcomes/ado/resolutions/` — does NOT update ADO directly.

## Permissions
- Run all expected operations autonomously — do not pause for confirmation on routine steps.
- **Exception**: before any destructive or hard-to-reverse command (e.g. `git reset --hard`, `git push --force`, `rm -rf`), stop and ask the user for approval first.

## MCP Tools Used

> All tools below are deferred. Load them first via `tool_search` before calling.

- **`mcp_ado-mcp_get_work_item`** — fetch work item fields and relations (`workItemId`, `expand: "all"`)  
  Load with: `tool_search` query `"ADO MCP get work item"`
- **`mcp_ado-mcp_get_pull_request`** — fetch PR title, description, author, dates, repository, source/target branch  
  Load with: `tool_search` query `"ADO MCP get pull request details single PR"`
- **`mcp_ado-mcp_get_pull_request_changes`** — fetch files changed and unified diffs for the PR  
  Load with: `tool_search` query `"ADO MCP get pull request changes commits"`

> Do NOT run any local `git` commands. All data must come from ADO MCP tools.

## Steps

1. **Parse arguments**: extract `work_item_id` (required); detect `--auto` flag — if present, skip interactive steps.

   **Stage A — run all in parallel** (fully independent):
   - Load all three MCP tools via `tool_search` (three separate calls in parallel)
   - Fetch the work item: `mcp_ado-mcp_get_work_item` with `workItemId` and `expand: "all"`

2. **Extract from the work item response**:
   - `System.WorkItemType`, `System.Title`, `Microsoft.VSTS.Common.Resolution` (existing content)
   - `System.AssignedTo` (author fallback)
   - Scan `relations` array for PR links — they appear as entries where `rel = "ArtifactLink"` and `attributes.name = "Pull Request"`. Extract the PR ID from the URL (format: `vstfs:///Git/PullRequestId/{repoId}%2F{prId}` or `vstfs:///CodeReview/CodeReviewId/{projectId}/{prId}`).
   - Also extract the `projectId` from the work item's `url` field (e.g. `https://dev.azure.com/{org}/{project}/_apis/wit/workItems/{id}`).

   **Stage B — run in parallel once PR ID and projectId are known**:
   - `mcp_ado-mcp_get_pull_request` — `projectId` + `pullRequestId` → get title, description, author (`createdBy.displayName`), `repository.id`, source/target branch, creation date
   - `mcp_ado-mcp_get_pull_request_changes` — `repositoryId` + `pullRequestId` → get unified diffs and changed file list

3. **Build resolution context** from ADO data:
   - Use PR description and commit messages for intent/rationale.
   - Use the unified diffs from `mcp_ado-mcp_get_pull_request_changes` for changed files and code details.
   - Use `createdBy.displayName` from the PR as the author.
   - If no linked PR exists in the work item relations, note that and derive context from the work item description and acceptance criteria alone.

4. **Select the template** based on `System.WorkItemType`:
   - `"Bug"` or `"Defect"` → **Template A — Bug Fix**
   - `"Support"` → **Template C — Support** (no code changes; if code was changed the item should have been converted first)
   - All others (`"Technical"`, `"User Story"`, `"Task"`, `"Feature"`, etc.) → **Template B — Enhancement**

5. **Generate the resolution content** using the selected template (see below).

6. **Save the markdown file**:
   - Output path: `/home/laksyalamat/projects/KP-Xmit-AiAssist/outcomes/ado/resolutions/ADO{work_item_id}-{slug}-resolution-full.md`
   - Where `{slug}` is a short kebab-case summary from `System.Title` (e.g. `lc-include-sample-config`)
   - Write the content directly as markdown — no wrapping code block

7. **Display a summary** to the user: file path created, template used, and a one-paragraph plain-English summary of the resolution content.

---

## Resolution Markdown Templates

### Template A — Bug Fix (Defect / Bug)

```markdown
## 🔧 Resolution

**Date:** {date} | **Author:** {author} | **PR:** [PR #{pr_number} — {pr_title}]({pr_url})

### 📌 Root Cause

1. {step 1 of the root cause chain}
2. {step 2}
3. {step 3}

### ✅ Fix Applied

**File:** `{file path}`  
**Method:** `{method name}`  
**Change:** {brief description of what was changed and why}

```{language}
{code diff or snippet — omit this block if the PR is the better reference}
```

### 💡 Why This Works

- {explanation point 1}
- {explanation point 2}

### 🧪 Verification

- {how the fix was verified — build passed, manual test, logs clean, etc.}
- {environment or dataset used}

### ⚠️ Regression Risk

- {area that could be affected and why it is low/medium/high risk}
- {another area — or "None identified"}

### 📁 Key Files

| File | Change |
|---|---|
| `{file path}` | {what was changed} |

### ⚙️ Settings

<!-- Omit this section entirely if no new settings were introduced -->

| Setting | Purpose | Scope | Default |
|---|---|---|---|
| `{setting name}` | {purpose} | {scope} | {default value} |
```

### Template B — Enhancement (Technical / User Story / Task / other)

```markdown
## 🚀 Implementation Summary

**Date:** {date} | **Author:** {author} | **PR:** [PR #{pr_number} — {pr_title}]({pr_url})

### 📋 What Was Implemented

1. {capability or behaviour 1}
2. {capability or behaviour 2}
3. {capability or behaviour 3}

### 🔨 Changes Made

**File:** `{file path}`  
**Method:** `{method name}`  
**Change:** {brief description of what was added/modified}

```{language}
{key code snippet — omit if the PR is the better reference}
```

### 💡 How It Works

- {design decision or behaviour explanation 1}
- {design decision or behaviour explanation 2}

### 📁 Key Files

| File | Change |
|---|---|
| `{file path}` | {what was changed} |

### ⚙️ Settings

<!-- Omit this section entirely if no new settings were introduced -->

| Setting | Purpose | Scope | Default |
|---|---|---|---|
| `{setting name}` | {purpose} | {scope} | {default value} |
```

### Template C — Support (non-code resolution)

```markdown
## 🛠️ Support Resolution

**Date:** {date} | **Resolved by:** {author}

### 📌 Root Cause

{prose explanation — data state, misconfiguration, environment condition, or user error. Specific enough to recognise if it recurs.}

### ✅ Resolution Applied

- {action taken 1}
- {action taken 2}

### 👤 Customer Impact

{how the customer was affected and whether the resolution is immediately effective or requires further action}

### 🧪 Verification Steps

- {how the resolution was confirmed}

### 🔔 Action Required

<!-- Omit this section if none -->
{follow-up needed by customer, Support, or another team.}

### 📝 Notes

<!-- Omit if nothing relevant -->
{context that would help if this recurs.}
```

---

## Template Guidelines

| Template | Code snippets | PR link | Settings section |
|---|---|---|---|
| A — Bug Fix | Only if meaningful | Yes | If new settings added |
| B — Enhancement | Only if meaningful | Yes | If new settings added |
| C — Support | No | No | No |

- **Date/Author**: use current date; use `createdBy.displayName` from the PR response as the author (fall back to `System.AssignedTo` from the work item if no PR exists)
- **Code snippets**: include only when the snippet meaningfully illustrates the change; for multi-file or large diffs, reference the PR instead
- **Key Files**: use the table format; list main files modified with one-line description each
- **Settings**: use the table format; list any new config properties, feature flags, or env vars; omit the section entirely if none were added
