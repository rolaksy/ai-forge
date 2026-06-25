---
name: pr-description
description: "Generate a detailed, structured PR description document for an Azure DevOps pull request. Use when: user asks to generate a PR description, write up a PR, create PR docs, describe a PR, summarize a pull request, document PR changes, get PR description for, or provides a PR ID or PR link and wants a write-up. Fetches PR details, changed files, diffs, and comments via ADO MCP, then produces a rich markdown description saved to outcomes/pr-descriptions/."
argument-hint: "<PR URL | PR ID>"
user-invocable: true
disable-model-invocation: false
---

# PR Description Skill

Generate a rich, structured PR description document from an Azure DevOps pull request.
The output is a standalone markdown file saved under `outcomes/pr-descriptions/` that can be copied directly into the PR description field or used as a reference.

## Non-Negotiable Rules

- Never write comments to the PR.
- Never update the PR description or any PR metadata in Azure DevOps.
- Never approve, reject, vote on, or modify the PR in any way.
- Only read PR data: title, description, diffs, changed files, linked work items, commits, and comments.
- Always save the generated description to `outcomes/pr-descriptions/`.
- Provide the saved file path and a brief summary to the user.

## PR Input Resolution

Accept these user inputs:

- Full Azure DevOps PR link (parse org, project, repo, PR ID from URL)
- PR ID only (ask which repository if ambiguous)
- Repository plus PR ID

Resolution order:

1. Full URL → parse all identifiers directly.
2. PR ID + current workspace context → use workspace repo from `my-projects-setup.instructions.md`.
3. PR ID with no context → ask the user for repository before fetching.

For the current workspace (`KP-Xmit-LinkCentral`), default to:
- Organization: `advantive-devops`
- Project: `Advantive`
- Repository: `KP-Xmit-LinkCentral`

## Data Collection Steps

Fetch these in parallel where possible:

1. **PR details** — `mcp_ado-mcp_get_pull_request` (title, description, author, status, source/target branch, created date, draft status, reviewers, merge status)
2. **Changed files + diffs** — `mcp_ado-mcp_get_pull_request_changes` (file paths, change types: added/modified/deleted, unified diffs)
3. **PR comments** — `mcp_ado-mcp_get_pull_request_comments` (reviewer threads, active/resolved status)
4. **Linked work items** — extract from PR details; fetch with `mcp_ado-mcp_get_work_item` for title, type, acceptance criteria, and description

Use the diffs to determine the *intent and impact* of each change — not just the file names.

## Output Generation

Load and follow `./references/pr-description-template.md` to produce the final document.

Key quality criteria:

- Each new class or file gets its own section with purpose, behavior, and design decisions inferred from the diff.
- Each modified file explains *what changed and why*, not just *that it changed*.
- New tests are listed individually with what they verify.
- A Mermaid architecture or sequence diagram is included when the change introduces or modifies a flow.
- The "Notes" section captures draft status, merge conflicts, missing reviewers, open comments, or deployment prerequisites.
- Credential values, tokens, passwords, and secrets are never included — even if visible in diffs (flag as a security note instead).

## Outcome Storage

Save the generated description as a markdown file in:

```text
outcomes/pr-descriptions/
```

Filename format:

```text
PR<pr-id>-description-<YYYYMMDD>.md
```

Example:

```text
outcomes/pr-descriptions/PR42785-description-20260528.md
```

Create `outcomes/pr-descriptions/` if it does not exist.

## Final Response to User

After saving, respond with:

1. The saved file path (as a clickable markdown link).
2. A one-paragraph summary of what the PR does.
3. The count of files changed (added / modified / deleted).
4. Any notable gaps or flags (e.g., draft PR, merge conflicts, no linked work item, open reviewer comments).
