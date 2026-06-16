---
name: ado-resolution-v2
description: "Generate a resolution document from an ADO work item and its PR. Use when: user says they completed an ADO task/story/technical item and provides a work item ID and/or PR URL; user asks to create a resolution, write up a resolution doc, or fill in the resolution template for an ADO item. Fetches all relevant details via ADO MCP (work item, PR, files changed, reviewers, dates) and produces a filled-in resolution markdown file in outcomes/ado-resolutions/."
argument-hint: "ADO work item ID and PR URL (e.g. 974347 https://dev.azure.com/.../pullrequest/42428)"
user-invocable: true
context: fork
---

# ADO Resolution v2

## Purpose
Automate creation of a filled-in resolution document by fetching all relevant data from Azure DevOps (work item + PR) and writing a markdown file based on the team's Resolution Template.

## When to Use
- User has completed an ADO work item and provides a work item ID and PR URL
- User says "create a resolution for ADO XXXXXX" or "fill in the resolution template"
- User provides a PR link and wants a resolution write-up

## Inputs Required
- **ADO Work Item ID** (e.g. `974347`)
- **PR URL** — extract `repositoryId`, `projectId`, and `pullRequestId` from the URL path:
  `https://dev.azure.com/{org}/{projectId}/_git/{repositoryId}/pullrequest/{pullRequestId}`
- **Repository name** (used for the Programs field)

## Procedure

### Step 1 — Read the Resolution Template
Read [../../templates/tesolution-template-v2.md](../../templates/tesolution-template-v2.md) to understand the expected structure before generating output.

### Step 2 — Fetch data in parallel via ADO MCP
Call all three simultaneously:
1. `mcp_ado-mcp_get_pull_request` — use `projectId` + `pullRequestId` from the URL
2. `mcp_ado-mcp_get_pull_request_changes` — use `repositoryId` + `pullRequestId`
3. `mcp_ado-mcp_get_work_item` — use `workItemId` with `expand: "all"`

### Step 3 — Extract key fields

From the **work item**:
- `System.Title` → document title / background heading
- `System.Description` → Background section
- `Microsoft.VSTS.Common.AcceptanceCriteria` → New Configuration / acceptance notes
- `Custom.QAAssigned.displayName` → QA assignee in QA checklist
- `Custom.DeveloperAssigned.displayName` → Dev in Dev checklist
- `System.IterationPath` → Sprint (for context)
- `Custom.Status` → current state

From the **PR**:
- `title` + `description` → Background / what was changed
- `createdBy.displayName` → Developer name
- `closedDate` → Date completed (format: dd/mm/yyyy)
- `reviewers[]` where `vote == 10` → Code reviewer who approved
- `sourceRefName` / `targetRefName` → Branch info

From **PR changes**:
- `changeEntries[].item.path` + `changeType` → Files Changed table
  - changeType `2` = Edit, `8` = Rename, `10` = Rename+Edit, `16` = Delete, `1` = Add

### Step 4 — Compose the resolution document

Follow the template structure:
1. **Fundamentals** — Background, Programs, PR Link, Branch
2. **Files Changed** — table of all changed/deleted/added files with descriptions
3. **Customer Setup** — Existing (NA unless customer-specific), New (config/script changes), Third-Party Setup (NA unless applicable)
4. **Dev checklist** — fill known entries; mark NA for inapplicable rows
5. **QA checklist** — leave blank for QA assignee to fill in

**Dev checklist rules:**
- "Dev's own test passed" → Yes / Laks Yalamati / `closedDate`
- "Code review passed" → Yes / `{approving reviewer}` / `closedDate`
- "QA preview passed" → Yes / Laks Yalamati / `closedDate` (if PR is merged/completed)
- "Unit test all passed" → Yes if tests exist in PR changes, else NA
- "New unit test added" → Yes if test files added/modified in PR changes, else NA
- All solution-discussed rows → NA unless work item comments indicate discussion

### Step 5 — Save the file

Output path: `/home/laksyalamat/projects/git/ai-forge/outcomes/ado-resolutions/ADO{workItemId}-{slug}-resolution.md`

Where `{slug}` is a short kebab-case summary derived from the work item title (e.g. `lc-include-sample-config`).

## Output Naming Convention
```
outcomes/ado-resolutions/ADO974347-lc-include-sample-config-resolution.md
outcomes/ado-resolutions/ADO884141-gopfert-link-bug-fix-resolution.md
```

## Notes
- Use `mcp_ado-mcp_get_pull_request` (project-scoped, no repositoryId) for the main PR fetch
- Use `mcp_ado-mcp_get_pull_request_changes` (requires repositoryId) for file diffs
- PR `status: 3` = completed/merged; `status: 1` = active
- Reviewer `vote: 10` = Approved; `vote: 5` = Approved with suggestions; `vote: -10` = Rejected
- changeType `16` = Delete (file removed); `8` = Rename only; `10` = Rename + edit
- All dates in resolution doc use `dd/mm/yyyy` format