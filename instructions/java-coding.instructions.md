---
applyTo: '**/*.java'
---

# Java Coding Instructions

## Style

- Prefer simple, explicit, readable Java.
- Avoid clever or overly compact code when it reduces maintainability.
- Preserve existing project style and naming conventions.
- Use 4-space indentation.
- Add Javadoc or inline comments only when the logic is complex, non-obvious, or business-critical.
- Do not add comments that simply repeat the code.

## Design Principles

- Follow SOLID, DRY, KISS, and YAGNI.
- Do not add new abstractions unless they clearly reduce duplication or improve testability.
- Avoid god classes, god services, and large methods.
- Prefer small, focused methods with clear names.
- Use interfaces and dependency injection for testability and flexibility, but do not over-engineer with unnecessary layers.
- Handle exceptions thoughtfully; do not catch and ignore without good reason.
- Consider thread safety and concurrency if applicable, but do not add unnecessary synchronization.

## Architecture Preference

When adding or changing backend code, prefer this design mindset:

```text
domain > service > adapter
```

Avoid making controllers or external adapters the center of the design.

## Error Handling

- Handle null and empty values explicitly where appropriate.
- Consider timeout, retry, and failure behavior when calling external systems.
- Do not swallow exceptions silently.
- Use meaningful exception messages.
- Avoid logging sensitive data.

## Change Scope

- Make minimal, targeted changes unless broader refactoring is requested.
- Ask before changing public APIs, method signatures, database schema, configuration, or build behavior.
- Do not refactor unrelated code.
- Do not change behavior unless explicitly requested or required to fix a defect.
