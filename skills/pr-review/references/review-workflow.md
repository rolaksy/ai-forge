# Review Workflow

Use this workflow for every PR review.

## 1. Identify the PR

Accept any of the following inputs:

- full Azure DevOps PR URL
- PR ID or PR number only
- repository and PR number
- current workspace branch with PR context

Resolve the input before fetching PR details:

1. If the user provides a full Azure DevOps PR URL, parse the organization, project, repository, and PR ID from the URL.
2. If the URL does not clearly identify the repository, ask the user which repository contains the PR.
3. If the user provides only a PR ID or PR number, ask the user which repository contains the PR.
4. If the user provides repository plus PR ID, use those values directly.
5. If the user points to the current workspace branch, use local git and Azure DevOps context to identify the PR. If the repository or PR ID remains ambiguous, ask only for the missing value.

Do not search across repositories for a bare PR ID unless the user explicitly asks you to do that.

Determine:

- organization
- project
- repository
- PR ID
- PR title
- PR description
- author
- source branch
- target branch
- latest commit
- changed files
- linked work items
- reviewers
- PR status

If the PR identity is ambiguous, ask for the minimum missing information.

## 2. Refresh Latest PR State

Always verify the latest PR state before reviewing.

When local git access is available, inspect:

```bash
git fetch origin
git status
git branch --show-current
git log --oneline -1
```

If the PR source branch is available:

```bash
git fetch origin <pr-source-branch>
git checkout <pr-source-branch>
git pull origin <pr-source-branch>
git log --oneline -1
```

Only review the latest available PR commit.

If the code cannot be refreshed, clearly state this as a limitation.

## 3. Read PR Description and Existing Comments

Read:

- PR title
- PR description
- commit messages
- existing PR comments
- active PR threads
- resolved PR threads
- screenshots or images in the PR
- developer test notes
- reviewer comments

Check for:

- linked work item IDs
- acceptance criteria references
- manual testing steps
- screenshots
- protocol names
- TDD links
- document links
- migration/config notes
- reviewer concerns
- “fixed” claims
- unresolved discussions

For every existing comment:

- determine whether the issue is still valid
- verify the actual code change
- do not assume resolved comments are correctly fixed
- flag incomplete fixes
- flag workarounds that do not address root cause
- check whether the fix introduces new issues

## 4. Fetch Work Item Context

For every linked work item, fetch:

- ID
- title
- type
- state
- description
- acceptance criteria
- repro steps if bug
- expected behavior
- actual behavior
- attachments
- hyperlinks
- comments
- parent
- children
- related items
- spike or research links

Always fetch the parent work item when present.

Always inspect child work items when they may contain:

- implementation detail
- QA notes
- subtasks
- technical requirements
- dependent functionality

Always inspect spike/research work items when present.

Treat spike findings as design constraints unless superseded by the current story or PR description.

## 5. Build Requirement Understanding

Before reviewing code, summarize the expected behavior from:

1. current work item acceptance criteria
2. parent feature
3. child tasks
4. spike/research work items
5. protocol documents
6. TDDs
7. PR description
8. existing comments
9. related implementation patterns

Create an internal requirement checklist:

```text
REQ-1:
Source:
Expected behavior:
Expected implementation:
Expected tests:
Risk:
```

Use this checklist to drive the code review.

## 6. Analyze Changed Code

Review actual code changes, not just descriptions.

For each changed file:

- understand why it changed
- inspect the diff
- inspect surrounding code
- inspect callers and callees when behavior may be affected
- inspect related tests
- inspect related configuration
- inspect related DTOs/contracts
- inspect related docs
- identify blast radius

Use Repomix MCP when broader context is needed.

Use Context7 MCP when framework/library behavior matters.

## 7. Perform Blast Radius Analysis

Check whether the PR affects:

- shared libraries
- public APIs
- DTOs/contracts
- protocol/message definitions
- database schema or queries
- configuration
- feature toggles
- frontend/backend contracts
- downstream products
- deployment behavior
- backward compatibility

Flag risks where downstream impact is unclear.

## 8. Check Backward Compatibility

For every API, protocol, DTO, config, or shared library change, verify:

- existing clients still work
- old protocol versions still route correctly
- JSON fields are not renamed or removed unexpectedly
- default config behavior remains safe
- feature toggles default safely
- breaking changes are documented and justified

## 9. Review Observability and Logging

Check whether the PR provides useful troubleshooting information without creating noise or leaking sensitive data.

Look for:

- useful logs for important failures
- actionable error messages
- no secrets in logs
- no unnecessary raw payload logging
- no noisy logs in loops unless guarded
- no production `console.log` or `console.error`
- clear exception context

## 10. Produce Evidence-Based Findings

Only report verified findings.

For each issue, include:

- title
- evidence
- why it matters
- suggested fix
- severity

Do not inflate severity for style preferences.

## 11. Save the Review Outcome

Save every completed review report as a markdown file under:

```text
outcomes/pr-review
```

Use this filename format:

```text
ADO<workitem>-pr-review-<date>-<time>.md
```

Use the current local date and time in this format:

```text
YYYYMMDD-HHMMSS
```

Example:

```text
outcomes/pr-review/ADO973277-pr-review-20260526-143012.md
```

For `<workitem>`, use the primary linked ADO work item ID. If several work items are linked, prefer the main story, bug, feature, or technical work item over implementation tasks. If the PR has no linked work item and the user did not provide one, ask the user for the work item ID before saving.

Create `outcomes/pr-review` if it does not exist.

In the chat response, include the saved file path and a concise summary of the review result.
