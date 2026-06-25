---
applyTo: '**/*.{java,js,jsx,ts,tsx}'
---

# Testing and Quality Instructions

## General Testing Rules

- Add or update tests when behavior changes.
- Prefer meaningful tests over coverage-only tests.
- Never change the target of a test just to make it pass.
- Do not use mocks only to inflate coverage.
- Integration tests should prefer real objects over mocks.
- Keep tests readable and maintainable.

## Backend Testing

- Use JUnit 5 unless the project already uses another framework.
- Use Mockito only when it adds value.
- Prefer testing business behavior and edge cases.
- Include tests for null, empty, invalid, timeout, and failure scenarios where relevant.

Coverage targets:

- 80% line coverage
- 70% branch coverage

## Frontend Testing

- Use Jest and React Testing Library where applicable.
- Test user-observable behavior.
- Avoid snapshot testing unless there is a clear reason.
- Do not couple tests tightly to implementation details.

## Automation and Regression Quality

- Prefer stable selectors and deterministic waits.
- Avoid brittle timing assumptions.
- For Selenium/Appium tests, consider browser/platform differences.
- When fixing flaky tests, identify the real synchronization or data issue rather than only increasing waits.

## Validation

After refactoring or behavior changes, run the relevant tests where possible.

If tests cannot be run, clearly state the recommended command and what it validates.
