# Acceptance Criteria Traceability

Use this reference to map requirements to implementation and tests.

## Requirement Sources

Extract requirements from:

- work item acceptance criteria
- work item description
- parent feature
- child tasks
- spike/research work items
- protocol documents
- TDD documents
- PR description
- existing review comments
- bug repro steps
- expected behavior sections

## Requirement Mapping Rules

For each requirement, identify:

- source of the requirement
- code that implements it
- unit/integration/controller/UI tests that verify it
- manual test evidence that supports it
- edge cases that should be covered
- missing coverage or uncertainty

Do not mark a requirement as met unless implementation evidence exists.

Do not mark test coverage as adequate unless the tests assert behavior, not just implementation details.

## Traceability Matrix

Use this table in the final report:

| Requirement | Source | Code Evidence | Test Evidence | Status | Notes |
|---|---|---|---|---|---|
| REQ-1 | ADO Work Item AC #1 | File/class/method | Test file/test name/manual evidence | Met / Partially Met / Not Met / Not Verified / N/A | Notes |

## Status Definitions

### Met

Use when:

- code evidence clearly implements the requirement
- tests or manual evidence adequately cover the behavior
- no material gaps are found

### Partially Met

Use when:

- some required behavior is implemented
- one or more cases are missing
- tests cover only part of the requirement
- manual evidence is incomplete

### Not Met

Use when:

- implementation is missing
- implementation contradicts the requirement
- behavior is likely incorrect based on code evidence

### Not Verified

Use when:

- required document or context is inaccessible
- code cannot be inspected
- test evidence is unavailable
- behavior depends on external state that cannot be verified

### Not Applicable

Use when:

- a requirement does not apply to the changed area
- the PR intentionally does not address it and scope confirms this

## Claims Verification

Treat these as unverified until confirmed:

- “All AC covered”
- “Tested successfully”
- “Fixed”
- “No impact”
- “Existing behavior unchanged”
- “Only refactoring”
- “No tests needed”

Verify with code and evidence.

## Edge Case Checklist

For each requirement, consider:

- null input
- empty input
- invalid input
- duplicate data
- missing required fields
- optional fields omitted
- boundary values
- zero values
- negative values
- large values
- timeout/failure response
- unsupported protocol version
- old client behavior
- partial failure
- retry behavior
- permission/auth failure

## Final Requirement Recommendation

Use one of these final outcomes:

- All acceptance criteria verified.
- Acceptance criteria mostly verified, with minor gaps.
- Acceptance criteria partially implemented.
- Acceptance criteria not fully verified due to limitations.
- Acceptance criteria not met.
