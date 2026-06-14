---
applyTo: '**'
---

# PR Review Instructions

## Review Style

When reviewing a PR, focus on correctness, maintainability, test coverage, security, and regression risk.

Prioritize important issues over style preferences.

## Review Checklist

Check for:

- functional correctness
- missed edge cases
- null and empty handling
- timeout and error handling
- backward compatibility
- cyclic dependencies
- unnecessary refactoring
- unrequested functionality
- logging of sensitive data
- input validation
- test coverage for changed behavior
- documentation updates where needed

## Java Review Focus

- Confirm Java version compatibility.
- Do not allow Java 11 repositories to use newer Java features.
- For Java 25 repositories, prefer conservative readable code.

## Testing Review Focus

- Tests should validate behavior, not implementation details.
- Integration tests should prefer real objects over mocks.
- Unit tests should not mock only to inflate coverage.
- Do not change the target of a test just to make it pass.

## Output Format

Use this format when summarizing PR review findings:

```md
## Summary

<short summary>

## Blocking Issues

- <issue>

## Non-Blocking Suggestions

- <suggestion>

## Testing Gaps

- <gap>

## Documentation Gaps

- <gap>
```

If there are no issues in a section, say `None found`.
