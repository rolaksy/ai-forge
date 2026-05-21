# Java / Spring / Maven Global Rules

Always inspect existing patterns before editing.

For Java:
- Prefer small, safe changes.
- Use constructor injection.
- Avoid circular dependencies.
- Keep controller, service, repository responsibilities separate.
- Do not introduce new dependencies unless justified.

For Maven:
- Check parent POM and dependency management first.
- Avoid pinning versions unless necessary.
- Explain dependency conflicts before changing versions.

For bugs:
Always provide:
- Issue Title
- Issue Description
- Reproduction Steps
- Observed Behavior
- Expected Behavior
- Root Cause, if known
- Fix Summary
- Test Evidence