---
applyTo: '**/*.{f,for,f90,f95,c,h}'
---

# Legacy Fortran and C Instructions

## Legacy Repositories

- `KP-MAP` is a legacy Fortran and C codebase.
- `KP-Xmit-XmitTests` contains legacy XMGEN tests.

## Change Strategy

- Avoid large refactoring unless explicitly requested.
- Prefer minimal, targeted fixes.
- Preserve existing behavior and conventions.
- Do not modernize legacy code just because newer patterns exist.
- Be careful with formatting-only changes because they can make diffs harder to review.

## Review Focus

When changing legacy code, clearly explain:

- what behavior changes
- what behavior is preserved
- risk areas
- how to test the change
- any compatibility concerns

## Safety

- Avoid changing public interfaces or data formats unless explicitly requested.
- Avoid introducing dependencies without approval.
- Be conservative with memory, file handling, and string/buffer operations.
