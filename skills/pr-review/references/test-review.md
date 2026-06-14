# Test Review

Use this reference to evaluate automated and manual test coverage.

## Automated Test Review

Check whether tests cover:

- all acceptance criteria
- happy paths
- negative paths
- boundary values
- null/empty input
- validation failures
- service failures
- backward compatibility
- protocol version behavior
- serialization/deserialization
- controller/API behavior
- UI behavior where applicable
- error handling
- edge cases from work items or protocol docs

## Java / Spring Tests

For Java and Spring changes, check:

- new controller endpoints have controller tests
- service logic has unit tests
- mapping/conversion logic has unit tests
- validation annotations are tested
- exception/error scenarios are tested
- tests use realistic data
- tests cover all required protocol fields where relevant
- Mockito usage is appropriate
- lenient Mockito is justified and scoped narrowly
- tests assert behavior, not just mock interactions
- test names describe behavior clearly

Controller tests should cover:

- success response
- validation failure
- service failure
- authorization/authentication impact where applicable
- request/response DTO shape
- status codes
- error body format

## React / Frontend Tests

For React changes, check:

- component renders expected behavior
- loading state is handled
- error state is handled
- empty state is handled
- user interactions are tested
- API failure is tested
- field validation is tested
- accessibility basics are covered where applicable
- no snapshot-only coverage for meaningful behavior
- hooks have correct dependencies
- state transitions are verified

## Protocol Test Requirements

For protocol implementations, check:

- all message types have tests
- request message generation is tested
- response parsing is tested
- XML serialization/deserialization is tested
- message framing is tested
- required fields are present
- optional fields are handled
- invalid/missing fields are tested
- protocol version behavior is tested
- reply triggers are tested where applicable
- realistic test data is used

Test data should include all relevant protocol fields, not just minimal examples.

## Manual Testing Evidence Review

If manual testing evidence is provided, inspect:

- manual steps
- expected result
- actual result
- screenshots
- environment
- browser/device/app version where relevant
- test data used
- positive cases
- negative cases
- edge cases

Manual test evidence should map to acceptance criteria.

Do not accept “tested successfully” without enough detail.

## Screenshot Review

When screenshots are attached:

- read visible UI text
- confirm screenshot matches changed behavior
- confirm screenshot is from the relevant environment
- verify before/after evidence if applicable
- check visible error messages
- check whether screenshot proves the claimed behavior
- flag screenshots that do not prove the requirement

## Missing Test Coverage Patterns

Common gaps to flag:

- only happy path tested
- no controller tests for new endpoints
- no test for validation failure
- no test for null/empty input
- no test for old protocol version
- no test for error path
- no frontend error/loading state test
- no test for config disabled/enabled behavior
- test data does not include all protocol fields
- tests assert implementation detail instead of outcome

## Test Review Output

Use this format:

```markdown
## Test Review

### Automated Tests
- Summary:
- Strong coverage:
- Missing coverage:

### Manual Tests
- Evidence reviewed:
- Coverage mapped to AC:
- Missing manual coverage:

### Recommended Additional Tests
1. ...
2. ...
```
