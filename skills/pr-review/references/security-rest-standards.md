# Security, Vulnerability, and REST Standards

Use this reference for all PRs, especially API, frontend, backend, dependency, and configuration changes.

## Security Checklist

Check for:

- secrets in code
- secrets in config
- secrets in tests
- secrets in logs
- secrets in screenshots
- sensitive data exposure
- missing authentication
- missing authorization
- insecure direct object access
- SQL injection risk
- command injection risk
- path traversal risk
- unsafe file handling
- unsafe XML parsing
- unsafe deserialization
- XSS in frontend code
- CSRF impact where relevant
- insecure CORS changes
- insecure headers
- insecure default config
- missing validation on external input
- dependency vulnerabilities introduced by the PR

## Logging and Sensitive Data

Check that logs do not expose:

- credentials
- tokens
- API keys
- session IDs
- customer-sensitive data
- raw protocol payloads unless safe and required
- personal data
- internal secrets

Logs should include useful troubleshooting context without leaking sensitive data.

## Vulnerability Classification

Classify security findings as:

- introduced by this PR
- made worse by this PR
- pre-existing but touched by this PR
- pre-existing unrelated issue
- false positive / not applicable
- needs separate security ticket

Do not block a PR for unrelated pre-existing vulnerabilities unless the PR makes the risk worse or depends on the vulnerable path.

## Dependency Review

When dependencies are added or changed, check:

- whether the dependency is necessary
- whether an existing dependency can be reused
- whether the version is current enough
- whether the dependency has known vulnerabilities
- whether it affects other modules/products
- whether license or size impact matters
- whether transitive dependencies are risky
- whether dependency scope is correct

## REST API Checklist

For API changes, verify:

- endpoint path follows existing conventions
- HTTP method matches behavior
- request DTO validates required fields
- response DTO is backward compatible
- status codes are meaningful
- error body format matches existing APIs
- controller remains thin
- service contains business logic
- API version differences are documented
- no breaking field rename/removal unless required and documented
- idempotency is considered where relevant
- pagination/filtering/sorting are considered where relevant
- authentication and authorization are unchanged or correctly updated

## API Versioning Review

When API versions are introduced or changed, check:

- purpose of each version is documented
- differences between versions are documented
- migration guidance exists if needed
- old clients remain supported if required
- version-specific tests exist
- controllers/services avoid unnecessary duplication

## Input Validation

Check that externally supplied input is validated at the boundary:

- required fields
- string length
- numeric range
- allowed enum values
- date/time format
- object ID format
- null/empty handling
- malformed payloads

## Output Safety

Check that responses do not expose:

- internal stack traces
- implementation details
- sensitive IDs unless required
- hidden/internal fields
- raw exception messages not intended for users

## Frontend Security

For React/frontend changes, check:

- no unsafe HTML injection
- no untrusted content rendered without escaping
- no sensitive data stored in local storage/session storage unnecessarily
- no secrets in frontend config
- API errors do not expose internals
- user input is validated and encoded appropriately
