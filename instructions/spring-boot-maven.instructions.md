---
applyTo: '**/{pom.xml,*.java}'
---

# Spring Boot and Maven Instructions

## Spring Boot Repositories

Known Spring Boot applications:

- `KP-Xmit-LinkCentral`
- `KP-Xmit-LinkDevice`
- `KP-Xmit-LinkDeviceSimulator`
- `KP-Xmit-LinkSimulator`
- `KP-Xmit-VLink-2.0`

## Spring Boot Guidelines

- Follow existing Spring Boot conventions in the repository.
- Keep controllers thin.
- Put business logic in service/domain layers.
- Keep adapters focused on integration concerns.
- Avoid mixing persistence, controller, and business logic in one class.
- Validate inputs at appropriate boundaries.
- Do not introduce new dependencies unless clearly justified.

## Maven Guidelines

- Respect parent POM and dependency management.
- Avoid hardcoding dependency versions if the parent POM or dependency management already controls them.
- Preserve module boundaries in multi-module builds.
- Do not introduce cyclic module dependencies.
- Keep plugin configuration consistent with existing project conventions.
- When changing Maven configuration, explain the build impact.

## Build Validation

When appropriate, suggest or run targeted Maven commands such as:

```bash
mvn test
mvn verify
mvn -pl <module> -am test
mvn -pl <module> -am verify
```

Prefer targeted module builds when working in large multi-module repositories.
