---
applyTo: '**'
---

# GitHub Copilot General Instructions

## Purpose

Follow project-specific coding, review, testing, documentation, troubleshooting, and security standards for Advantive/Kiwiplan projects.

These instructions apply globally. Rules in `~/projects/KP-Xmit-AiAssit/instructions/*.instructions.md` whose filename or applyTo glob matches the current file or task type take priority over these general instructions. If there are conflicting rules between this file and a more specific instructions file, the more specific file's rules take precedence.

## General Working Style

- Prefer simple, readable, maintainable solutions.
- Follow SOLID, DRY, KISS, and YAGNI.
- Do not add new functionality unless explicitly requested.
- Make minimal, targeted changes unless a broader refactor is requested.
- Ask before major refactoring, public API changes, database schema changes, configuration changes, or build pipeline changes. If the user explicitly instructs you to proceed without confirmation, document the risky change inline with a comment or warning block before implementing it.
- Preserve existing project style and conventions unless there is a clear defect or risk.
- Avoid speculative rewrites.
- Always consider null, empty values, timeouts, error handling, logging, and backward compatibility.
- Always look in /home/laksyalamat/projects/KP-Xmit-AiAssit/outcomes for relevant past outcomes before proceeding / research outputs / implementation plan etc to get context and avoid redundant work. If this path does not exist in the current environment, skip this step and proceed without past outcomes context. Do not fabricate or assume outcomes content.

## Codebase Exploration

- When analyzing a repository, always check for an existing repomix output before packing.
- If no previous repomix output is found, pack the local repository using repomix mcp server before proceeding with analysis. If the repomix MCP server is unavailable or returns an error, state this explicitly and proceed with direct file-by-file exploration, noting that full context may be incomplete.

## Project Context

Primary project root:

```text
/home/laksyalamat/projects
```

Most work is in Java repositories. Some repositories include React frontends. Legacy XMGEN/Fortran/C work is rare and should be handled conservatively.

## Java Defaults

- Do not assume all projects use the same Java version.
- Use repository-specific Java rules.
- Java 11 projects must not use newer Java language features.
- Java 25 projects should default to Java 17-compatible language features (records, sealed classes, pattern matching for instanceof are acceptable). Avoid virtual threads, value types, or other Java 21+ features unless explicitly requested.
- Prefer clear object-oriented code over clever or overly compact code.
- Avoid cyclic package dependencies, especially in:

```text
com.kiwiplan.linkcentral.comms.core
```

## Backend Architecture

- Prefer domain-oriented structure.
- Use this ordering mindset where suitable:

```text
domain > service > adapter
```

- Avoid introducing controller-driven or god-service designs.
- Keep responsibilities isolated.
- Avoid large methods/classes when small focused extraction improves readability.

## Frontend Defaults

- Use React functional components and hooks.
- Keep components small, reusable, and testable.
- Prefer feature-based folder organization.
- Avoid god components.
- Use 2-space indentation for JavaScript/React.

## Testing and Quality

### Coverage Targets (hard minimums)

- Backend line coverage: minimum 80%.
- Backend branch coverage: minimum 70%.
- These are hard minimums. Strive to exceed them where practical, but do not sacrifice test quality to hit numbers.

### Test Design Rules

- Add or update tests when behavior changes.
- Backend tests should use JUnit 5 unless the project already uses a different framework.
- Frontend tests should use Jest and React Testing Library where applicable.
- Aim for meaningful coverage, not coverage inflation.
- Avoid snapshot testing unless there is a clear reason.
- Integration tests should prefer real objects over mocks.
- Unit tests should not mock only to inflate coverage.
- Never change the target of a test just to make it pass.

## Documentation

- Update README or docs when adding a feature, workflow, script, configuration, or notable behavior change.
- Use clear markdown headings and fenced code blocks.
- Label multiple code snippets with file path and purpose.
- Use Mermaid diagrams for architecture.
- Use SVG for non-architecture diagrams.

## Security and Compliance

- Never expose secrets in code, logs, test data, generated docs, or examples.
- Validate backend and frontend inputs.
- Avoid logging sensitive values.
- For Electron apps, use secure IPC and avoid insecure direct DOM manipulation from preload scripts.

## CLI and Environment

Use SDKMAN for Java version switching:

```bash
sdk use java 11.0.19-amzn
sdk use java 17.0.19-amzn
sdk use java 25.0.3-amzn
```

Do not create shell script files only to test functionality unless explicitly requested.

## Validation

- After refactoring, rerun relevant tests.
- For build, dependency, or environment changes, provide the exact command used or recommended.
- If tests cannot be run, clearly state what should be run manually.
