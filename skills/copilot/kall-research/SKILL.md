---
name: kall-research
description: "Research an XMIT KALL number and generate a Markdown findings document. Use when: user invokes /kall-research with a KALL number, asks to investigate a KALL, look up KALL or SCM information, summarize work completed for a KALL, or continue an interrupted KALL research workflow."
argument-hint: "<kall_number | continue>"
user-invocable: true
context: fork
---

# KALL Research

## Invocation

- `/kall-research <kall_number>`: begin a new investigation for the specified KALL number.
- `/kall-research continue`: continue the current investigation after an interruption or error. Determine the resume point from recent chat history, existing notes, and the current research document.

If the user invokes this skill without a KALL number or `continue`, ask for the KALL number before starting.

## Purpose

Research an XMIT KALL number and create or update a Markdown findings document that explains:

- what work was completed for the KALL number
- why the work was done
- surrounding product or domain context
- affected code areas
- related Azure DevOps work items, KALL numbers, SCM numbers, pull requests, documentation, and support resources

The research does not need to be exhaustive. The goal is to give software developers and testers a clear, practical understanding of the completed work and the evidence behind it.

## Audience

Software developers and testers.

## Required Tools

Use the most specific MCP tool available for each data source:

- Use the Repomix MCP to pack the target codebase before code investigation.
- Use the Repomix MCP when reading code or searching the codebase for this workflow.
- Use the Azure DevOps MCP when fetching Azure DevOps work items, pull requests, linked items, comments, or related ADO metadata.
- Use the AdvantiveGPT MCP when searching product documentation, knowledge base articles, support how-tos, KALL numbers, SCM numbers, KALL details, or SCM details.

If a required MCP tool is unavailable, state the blocker clearly, record it in the research document, and continue only with sources that are available and appropriate.

## Working Rules

- Work one step at a time.
- At the start of each step, state which step is in progress.
- At the end of each step, state that the step is complete and proceed to the next step without asking for confirmation unless blocked.
- Update the Markdown document at each step with findings, evidence, open questions, and source links or identifiers.
- Prefer concise findings with enough detail for a developer or tester to continue the work.
- Do not expose secrets, credentials, private tokens, or sensitive customer data in the document.
- When continuing, inspect the existing research document first and resume from the first incomplete or weakly supported section.

## Step 0: Prerequisites

1. Identify the target repository or codebase for the KALL investigation.
2. Use the Repomix MCP to pack the target codebase into a searchable index before code research begins.
3. Confirm the available MCP sources for Repomix, Azure DevOps, and AdvantiveGPT.
4. Add or update a `Prerequisites` section in the research document with:
   - target repository or codebase
   - Repomix pack status
   - MCP sources available
   - date of investigation
   - any blockers or limitations

After completing this step, continue to Step 1.

## Step 1: Create Document

1. Find or create the active target project's `outcomes` directory.
2. Create or reuse a folder named `KALL-research` inside that `outcomes` directory.
3. Create or reuse a Markdown file named after the KALL number, using this pattern: `<kall_number>.md`.
4. If the target project cannot be identified, ask the user which project's `outcomes` directory to use before creating the research document.
5. If the file already exists, preserve existing useful content and continue improving it.
6. Use internal file tools to create the folder and file when available.

Initialize the document using the [KALL research template](./references/kall-research-template.md).

After completing this step, continue to Step 2.

## Step 2: Research the KALL Number

1. Use the AdvantiveGPT MCP to search for the XMIT KALL number.
2. Search for direct references to the KALL number and related terms, including:
   - `KALL <kall_number>`
   - the bare KALL number
   - known SCM numbers found during research
   - related ADO work item IDs found during research
   - related customer, site, protocol, module, feature, or defect terms found during research
3. Capture relevant facts in the `KALL Details`, `Related Items`, `Domain Context`, and `Sources` sections.
4. Record source identifiers, titles, URLs, dates, or tool result names where available.
5. Note conflicting or incomplete information in `Open Questions`.

After completing this step, continue to Step 3.

## Step 3: Research Related Work Items and SCM References

1. Use AdvantiveGPT MCP to look up related SCM numbers, KALL numbers, and support references discovered in Step 2.
2. Use Azure DevOps MCP to fetch any related ADO work items, pull requests, linked items, discussion, state, assignee, acceptance criteria, and implementation notes.
3. Record each related item with a short explanation of why it matters.
4. Update `Related Items`, `Findings`, `Open Questions`, and `Sources`.

After completing this step, continue to Step 4.

## Step 4: Research Affected Code Areas

1. Use the Repomix MCP searchable index to search the target codebase for the KALL number, related SCM numbers, related work item IDs, and important domain terms discovered earlier.
2. Identify affected modules, packages, classes, configuration, tests, scripts, or documentation.
3. Summarize code behavior at a level useful to developers and testers.
4. Avoid broad refactoring or code changes unless the user explicitly asks for implementation work.
5. Update `Code Areas Reviewed`, `Findings`, `Developer and Tester Notes`, and `Sources`.

After completing this step, continue to Step 5.

## Step 5: Synthesize Findings

1. Write a concise `Summary` that explains what was done and why.
2. Add practical testing notes, including affected workflows, likely regression areas, and data/setup considerations.
3. Add developer notes for code ownership, risky areas, assumptions, and follow-up work.
4. Ensure every key claim has a source or clear evidence trail.
5. Leave unresolved items in `Open Questions` rather than guessing.

After completing this step, continue to Step 6.

## Step 6: Final Review

1. Review the Markdown document for clarity, completeness, and safe handling of sensitive information.
2. Ensure the document is useful for both developers and testers.
3. Confirm the document path to the user.
4. Summarize the main findings, source coverage, and any remaining gaps.

## Output Expectations

When the skill completes, report:

- the research document path
- the KALL number researched
- the primary findings
- related ADO work items, KALL numbers, SCM numbers, or PRs found
- code areas reviewed
- remaining open questions or tool/source limitations
