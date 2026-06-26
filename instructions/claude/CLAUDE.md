---
applyTo: "**"
---

# Unified AI Instructions (Shared Across Claude and Copilot)

## Purpose

- Define one shared baseline for both Claude and Copilot harnesses.
- Delegate file-type and domain-specific rules to the files in `instructions/common/`.

## Instruction Resolution Order

1. Direct user instruction.
2. Matching file/task-specific instructions in `instructions/common/*.instructions.md`.
3. This shared baseline file.
4. Existing repository conventions.

If instructions conflict, apply the most specific matching rule.

## Mandatory Delegation to `instructions/common`

- For any markdown or documentation output (`*.md`), follow `instructions/common/documentation.instructions.md`.
- For Java code, follow both:
	- `instructions/common/java-coding.instructions.md`
	- `instructions/common/java-version-rules.instructions.md`
- For Spring Boot or Maven-related work, follow `instructions/common/spring-boot-maven.instructions.md`.
- For React/frontend files (`*.js`, `*.jsx`, `*.ts`, `*.tsx`, `*.css`, `*.scss`, `*.html`), follow `instructions/common/react-frontend.instructions.md`.
- For Java/JS/TS test quality expectations, follow `instructions/common/testing-quality.instructions.md`.
- For Fortran/C legacy files, follow `instructions/common/legacy-fortran-c.instructions.md`.
- For all security-sensitive concerns, follow `instructions/common/security-and-compliance.instructions.md`.
- For debugging/troubleshooting tasks, follow `instructions/common/troubleshooting-debugging.instructions.md`.
- For repository landscape and setup context, follow `instructions/common/my-projects-setup.instructions.md`.

## Working Principles

- Think before acting. Make assumptions explicit when they affect implementation.
- Ask concise clarifying questions when ambiguity changes outcome.
- Prefer minimal, targeted changes. Avoid speculative rewrites.
- Match existing style and architecture patterns.
- Keep solutions simple and maintainable (SOLID, DRY, KISS, YAGNI).
- Do not add functionality that was not requested.
- Do not create `.claude` files or other AI-related workspace files unless the user explicitly requests them.
- Preserve backward compatibility unless the user explicitly approves a breaking change.
- Ask before major refactors, public API changes, database schema changes, configuration changes, or build pipeline changes.
- Read affected exports, callers, and shared utilities before editing.

## Execution and Validation

- Define success criteria and verify before finishing.
- Add or update tests when behavior changes.
- Run relevant validation commands when possible.
- If validation cannot be run, state exact manual commands and what they verify.
- Report failures/blockers with concrete evidence. Do not fabricate outcomes.

## Project Context Practices

- Primary root: `/home/laksyalamat/projects/git/ai-forge`.
- Check `/home/laksyalamat/projects/git/ai-forge/outcomes` for relevant prior outputs before deep analysis.
- For large analysis tasks:
	- Check for existing repomix packed outputs first.
	- If missing and tooling is available, pack before deep analysis.
	- If tooling is unavailable, continue with direct file analysis and state that limitation.

## Output File Rules

- Never create plans, analysis docs, implementation guides, or any `.md` output files inside working repos (e.g. KP-Xmit-*, KP-MAP, etc.). Working repos are for production code only.
- All such outputs must go to `/home/laksyalamat/projects/git/ai-forge/outcomes/<subfolder>/`.
- Always run `ls /home/laksyalamat/projects/git/ai-forge/outcomes/` first and pick an existing subfolder. Never create a new subfolder without checking what already exists.

## Security Baseline

- Never expose secrets, tokens, credentials, or private keys.
- Avoid logging sensitive values.
- Treat external inputs/responses as untrusted and validate at boundaries.
- Do not add dependencies unless necessary and compatible with repository conventions.

## Communication Style

- Be concise, direct, and specific.
- Avoid filler phrasing.
- For multi-step work, checkpoint clearly: done, verified, next.
- Separate facts, assumptions, and recommendations when summarizing.