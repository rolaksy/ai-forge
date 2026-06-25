# Review Report Template

Use this final report format for every PR review.

```markdown
# PR Review Report

## Review Summary

Overall Result: Pass / Pass with Concerns / Needs Changes / Partial Review

Review Confidence: High / Medium / Low

Summary:
[One concise paragraph explaining what the PR changes and the main review outcome.]

## Scope Reviewed

- PR:
- Repository:
- Source branch:
- Target branch:
- Latest commit reviewed:
- Work items reviewed:
- Parent work items reviewed:
- Child work items reviewed:
- Spike/research work items reviewed:
- Documents reviewed:
- Files reviewed:
- Existing PR comments reviewed:

## Requirement Coverage

| Requirement | Source | Code Evidence | Test Evidence | Status | Notes |
|---|---|---|---|---|---|
| REQ-1 |  |  |  | Met / Partially Met / Not Met / Not Verified / N/A |  |

## Findings

Only list negatives and improvements. Do not include positives or praise.

| # | Severity | Area | Finding | Evidence | Impact | Suggested Fix |
|---|---|---|---|---|---|---|
| F01 | Critical / Important / Suggestion | [Area] | [What is wrong] | [File/method/line/diff] | [What breaks or degrades] | [Specific fix] |

**Severity key:** Critical = must fix before merge · Important = should fix · Suggestion = nice to have

## Test Analysis

| # | Test ID | Type | Description | Status | Gap / Concern |
|---|---|---|---|---|---|
| 1 | TC01 | Unit / Integration / Manual / UI | [What the test covers] | Pass / Fail / Missing / Partial | [Missing scenario, weak assertion, no evidence, etc.] |

**Status key:** Pass = confirmed present and adequate · Fail = confirmed broken · Missing = required but absent · Partial = exists but insufficient

## Security and REST Review

### Security

- Security concerns:
- Vulnerability classification:
- Sensitive data/logging concerns:

### REST/API

- Endpoint/versioning concerns:
- Request/response DTO concerns:
- Validation concerns:
- Backward compatibility concerns:

## Documentation Review

- Protocol documents reviewed:
- TDD reviewed:
- API documentation:
- Feature toggle/config documentation:
- Missing or unclear documentation:

## Limitations

List anything not accessible or not verified.

Examples:

- Could not access parent feature attachments.
- Protocol document was not available.
- Manual screenshots were not attached.
- Unit tests were not runnable locally.
- Latest PR branch could not be fetched.

## Final Recommendation

Choose one:

- Ready to merge
- Ready after minor fixes
- Needs changes before merge
- Partial review only — do not rely on this for final approval

Recommendation:
[Clear final recommendation with reason.]
```

## Severity Guidance

### Critical

Use for:

- acceptance criteria not implemented
- protocol behavior incorrect
- likely runtime exception
- security vulnerability introduced
- data corruption risk
- incorrect mapping or scaling
- broken API contract
- missing tests for core new behavior
- merge conflict markers
- stale code review state
- backward compatibility break

### Important

Use for:

- weak edge-case coverage
- unclear API documentation
- maintainability concern
- duplicated logic
- missing observability
- risky but unlikely edge case
- incomplete manual testing evidence
- unclear feature toggle behavior

### Suggestion

Use for:

- naming improvement
- minor refactor
- optional extra comments
- extra non-critical tests
- readability improvement

## Review Confidence Definitions

### High

Use when:

- latest code was reviewed
- work items were accessible
- parent/child/spike context was checked
- required documents were accessible
- tests and manual evidence were reviewed
- no major context gaps remain

### Medium

Use when:

- code and main work item were reviewed
- some supporting context was missing
- tests were partially reviewed
- some documents or evidence were unavailable

### Low

Use when:

- latest code could not be verified
- work item context was missing
- key documents were inaccessible
- tests could not be inspected
- review is mostly based on partial evidence
