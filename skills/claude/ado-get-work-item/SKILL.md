---
name: ado-get-work-item
description: "Fetch Azure DevOps work item details by ID using MCP tools, formatted for Claude Code workflows. USE FOR: inspect fields, acceptance criteria, links, and implementation context."
argument-hint: "<work_item_id> [--expand=none|relations|fields|links|all] [--extra-fields=csv]"
user-invocable: false
disable-model-invocation: false
---

# ado-get-work-item

## Purpose

Fetch a single Azure DevOps work item using MCP tools, then return Claude-friendly structured Markdown plus raw JSON.

## Inputs

- `work_item_id` (required): numeric ADO work item ID
- `--expand` (optional): one of `none`, `relations`, `fields`, `links`, `all` (default: `all`)
- `--extra-fields` (optional): comma-separated field names to surface prominently in the summary

## Required Tooling

Use this MCP tool:

- `mcp_azure-devops-_get_work_item`

Do not call Python skill scripts for retrieval.

## Core Workflow

1. Parse inputs.
2. Call `mcp_azure-devops-_get_work_item` with:
   - `workItemId = <work_item_id>`
   - `expand = <expand or all>`
3. If tool call fails, return a compact error block with likely cause and next action.
4. If successful, produce output in two sections:
   - `## Human Summary`
   - `## Raw JSON`

## Human Summary Format (Claude-Optimized)

In `## Human Summary`, include only the most decision-useful data first:

1. `ID`, `Type`, `Title`, `State`, `Assigned To`, `Priority`, `Area Path`, `Iteration Path`
2. `Description` (trim noise, preserve meaning)
3. `Acceptance Criteria` when present
4. `Resolution` when present
5. `Tags`
6. `Relations` summary (parent/child/related links grouped by relation type)
7. `Requested Extra Fields` from `--extra-fields` in a dedicated subsection
8. `Gaps / Missing Data` (explicitly list missing important fields)

Then include `## Raw JSON` with the unmodified tool response in a fenced `json` block.

## Output Rules

- Keep the summary concise and scannable for coding agents.
- Preserve original field values in Raw JSON.
- Never invent field values.
- If a field is unavailable, state `Not available`.
- If relation URLs exist without titles, still list them.

## Error Handling

On errors, return:

```md
## Error
- Work item: <id>
- Source: mcp_azure-devops-_get_work_item
- Message: <exact tool error when possible>
- Suggested next step: <single actionable step>
```

## Model Preference

If model selection is supported for delegated execution, prefer:

- `Claude Sonnet 4 (copilot)`

If unavailable, use the default configured model and continue.

## Example Tool Call

- Tool: `mcp_azure-devops-_get_work_item`
- Args:
  - `workItemId: 44206`
  - `expand: "all"`
