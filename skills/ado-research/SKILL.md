---
name: ado-research
description: >
  Research an Azure DevOps Work Item using the ADO MCP, Repomix, and AdvantiveGPT MCPs,
   then generate a structured research document saved to /home/laksyalamat/projects/KP-Xmit-AiAssist/outcomes/ado/research/.
  Output filename format: ADO<id>-research-<datetime>.md
  Use when: user types /research <work_item_id>; user asks to investigate, research,
  or kick-start analysis on an ADO work item; user wants a research doc generated for a ticket.
argument-hint: "<work_item_id>"
user-invocable: true
context: fork
---

# ADO Research Skill

## Invocation

```
/research <work_item_id>      — begin a new investigation for the specified work item
/research continue            — resume an interrupted investigation from where it left off
```

If no work item ID is provided, prompt the user for it before proceeding.

---

## Purpose

You are an experienced software engineer with deep knowledge of the codebase and the surrounding product domain. Research the specified Azure DevOps Work Item and produce a `research.md` document that kick-starts a developer or tester before they begin their own deeper investigation and implementation.

The document does not need to be exhaustive. Its goal is to orient the reader: clarify the problem, surface relevant domain knowledge, identify affected code areas, and suggest concrete next steps.

**Target audience:** Software developers and testers.

---

## Tool Assignments

| Concern | Tool to Use |
|---|---|
| Codebase analysis and search | Repomix MCP (`pack_codebase`, `grep_repomix_output`, `read_repomix_output`) |
| Azure DevOps work item data | ADO MCP (`get_work_item`) |
| Product docs / KB / user guides | AdvantiveGPT MCP (`list_indexes`, `search`) |
| File and folder creation | Filesystem MCP (`create_directory`, `write_file`) or built-in file creation tools |

Never use terminal commands to create files or directories unless the MCP filesystem tools are unavailable.

---

## Execution Rules

- Work **one step at a time**. State which step you are starting before beginning it.
- After each step completes, state it is done and proceed to the next step automatically — do not pause and ask the user unless an input is genuinely missing.
- Update `research.md` at the end of each step as you go — do not batch all writes to the end.
- If `/research continue` is invoked, review recent chat history to determine which step was last completed, then resume from the next step.

---

## Steps

### Step 0 — Prerequisites

1. **Identify the workspace root:** Use the currently open VS Code workspace folder as the codebase root. If multiple folders are open, ask the user which repository to research before proceeding.
2. **Pack the codebase:** Use the **Repomix MCP** (`pack_codebase`) with the workspace root path to pack the codebase into a searchable index. Store a reference to the packed output ID for use in Step 4. Do not use a hardcoded path — always derive it from the active VS Code workspace.
3. Confirm the following MCPs are available and will be used throughout:
   - **ADO MCP** — for all Azure DevOps data
   - **Repomix MCP** — for all codebase searches (always using the packed output from this step)
   - **AdvantiveGPT MCP** — for all product documentation and knowledge base searches

---

### Step 1 — Create Research Document

**Output path:** `/home/laksyalamat/projects/KP-Xmit-AiAssist/outcomes/ado/research/`
**Filename format:** `ADO<work_item_id>-research-<datetime>.md`
  - `<datetime>` must be the current date and time at the moment the file is created, formatted as `YYYYMMDD-HHmmss` (e.g., `ADO12345-research-20260526-143022.md`).
  - Each invocation always creates a new file with a fresh timestamp — never overwrite an existing file.

1. Create the folder `/home/laksyalamat/projects/KP-Xmit-AiAssist/outcomes/ado/research/` if it does not already exist.
2. Determine the current date and time and construct the full filename: `ADO<work_item_id>-research-<datetime>.md`.
3. Create the file at the resolved path.
4. Initialise the document using the structure below. Use plain-text placeholders for all sections that have not yet been populated:

```markdown
# [Title Placeholder]

## Work Item Type
[Work item type placeholder]

## Module
[Module placeholder]

### Current Activity
Researching work item — in progress.

### Description
[Description placeholder]

### References
[References placeholder]

### Domain Questions
[No domain questions researched yet]

### Code Questions
[No code questions researched yet]

### Recommended Next Steps
[To be determined]
```

5. Write this initial content to the file and confirm the full file path to the user.

---

### Step 2 — Fetch Work Item from Azure DevOps

1. Use the **ADO MCP** (`get_work_item`) to fetch the work item by ID.
2. Extract the following fields:

   | Field | ADO Field Reference |
   |---|---|
   | ID | `System.Id` |
   | Title | `System.Title` |
   | Work Item Type | `System.WorkItemType` |
   | Module | `Custom.Module` |
   | Description | `System.Description` |
   | Acceptance Criteria | `Microsoft.VSTS.Common.AcceptanceCriteria` |
   | Steps to Reproduce | `Custom.StepstoReproduce` |
   | Comments / History | `System.History` |
   | Attachments & Hyperlinks | From `relations` — capture `attributes.name` and `url` |

3. Update the research document:
   - **H1 Title** — set to the work item title.
   - **Work Item Type** — set from extracted value.
   - **Module** — set from extracted value.
   - **Description** — write a rigorous summary focused on helping a developer or tester understand the ask. Include: what the issue is, what the expected behavior is, reproduction steps if present, and acceptance criteria. Strip HTML if necessary and format as clean Markdown.
   - **References** — list all attachments and hyperlinks extracted from relations.

---

### Step 3 — Domain Research with AdvantiveGPT

**Goal:** Surface relevant product documentation, user guides, or knowledge-base articles that give context for this work item.

1. Use the **AdvantiveGPT MCP** (`list_indexes`) to retrieve available indexes.
2. Based on the **Module** field from Step 2, select the most appropriate index. Use `kiwiplangpt` or `kiwiplan-xmgengpt` for Kiwiplan/XMGEN-related modules. When in doubt, prefer the index whose name best matches the module name.
3. Conduct **exactly 3 rounds** of question and answer. For each round:
   a. Propose one plain-English question that would surface useful domain context (product behavior, configuration, troubleshooting guidance). Do not combine multiple topics into one question.
   b. Update the **Domain Questions** section in the research document with the proposed question.
   c. Call **AdvantiveGPT MCP** (`search`) with the question and selected index.
   d. Update the **Domain Questions** section in the research document immediately with the answer (or a note that the answer was not helpful). Include a brief summary of what was found.
   e. If the response is helpful and a targeted follow-up would add meaningful value, ask one follow-up question (counts as one of the 3 rounds).
   f. Do not repeat a question or a close variation of a question already asked.
4. After all 3 rounds, confirm the **Domain Questions** section is fully updated before continuing.

**Good question examples:**
- "What is the expected behavior of the system when [action X] occurs?"
- "What are the recommended troubleshooting steps for an issue with [feature Y]?"
- "What configuration options control [behavior Z]?"

**Avoid:** questions about code or implementation (those belong in Step 4).

---

### Step 4 — Code Research with Repomix

**Goal:** Identify the relevant areas of the codebase that relate to this work item.

1. Use the packed Repomix output from Step 0 for all searches.
2. Conduct **exactly 3 rounds** of question and answer. For each round:
   a. Propose one question targeting code understanding. Focus on locating features, tracing logic, or identifying files that will need to change.
   b. Update the **Code Questions** section in the research document with the proposed question.
   c. Use **Repomix MCP** (`grep_repomix_output` or `read_repomix_output`) to search the packed codebase and answer the question.
   d. Update the **Code Questions** section in the research document immediately with the answer. Include specific file paths and function/method names where found.
   e. Do not repeat a question or a close variation of a question already asked.
3. After all 3 rounds, confirm the **Code Questions** section is fully updated before continuing.

**Good question examples:**
- "Where is the code that handles [feature X]?"
- "What logic is used to calculate or process [value Y]?"
- "Which files will likely need to change to implement [requirement Z]?"

---

### Step 5 — Recommended Next Steps

1. Review the full research document — all findings from Steps 2, 3, and 4.
2. Generate a prioritised, actionable list of recommended next steps for the developer or tester who picks up this work item. Each step should be concrete and specific to the findings.
3. Update the **Recommended Next Steps** section in the research document.
4. Update the **Current Activity** section to: `Research complete.`
5. Confirm the final document is saved and output the full file path to the user (e.g., `/home/laksyalamat/projects/KP-Xmit-AiAssist/outcomes/ado/research/ADO12345-research-20260526-143022.md`).

---

## Error Handling

- If the ADO MCP fails to fetch the work item, inform the user of the error and suggest verifying the work item ID and ADO connectivity. Do not proceed until the work item is successfully fetched.
- If AdvantiveGPT returns no useful results for the selected index, try one alternative index before moving on.
- If Repomix pack fails, inform the user and ask them to check the project root path.
- If any step fails or is interrupted, inform the user with a clear description of what went wrong, then instruct them to type `/research continue` to resume from the last completed step.
