---
applyTo: '**'
---

# Security and Compliance Instructions

## Secret Handling

- Never expose secrets in code, logs, tests, docs, examples, generated files, or comments.
- Do not commit tokens, passwords, PATs, private keys, connection strings, or credentials.
- Use environment variables, secret managers, or existing secure configuration patterns.
- Avoid printing sensitive values in logs.

## Input Validation

- Validate backend inputs at service/API boundaries.
- Validate frontend inputs before submission where appropriate.
- Treat external system responses as untrusted.
- Handle malformed, missing, empty, and unexpected values safely.

## Logging

- Log enough information to troubleshoot issues.
- Do not log credentials, tokens, customer-sensitive data, or personal data.
- Prefer IDs and safe context over raw payloads when possible.

## Frontend and Electron

- Avoid unsafe DOM manipulation.
- For Electron/preload code, use secure IPC messaging.
- Do not expose broad privileged APIs to the renderer.
- Keep context isolation and least-privilege principles in mind.

## Dependency Safety

- Do not add new dependencies unless necessary.
- Prefer existing approved libraries and project patterns.
- Consider dependency version compatibility, licensing, and security impact.
