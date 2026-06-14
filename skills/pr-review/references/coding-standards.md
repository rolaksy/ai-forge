# Coding Standards Review

Use this reference to evaluate general code quality across Java, React, REST APIs, and legacy code.

## General Standards

Check for:

- correctness
- maintainability
- readability
- clear naming
- small focused methods/functions
- single responsibility
- low duplication
- low coupling
- appropriate abstraction
- no dead code
- no unused imports
- no debug leftovers
- no merge conflict markers
- consistent formatting
- consistency with nearby code

## AI-Generated Code Risk Checks

When code appears generated or heavily assisted by AI, check for:

- over-engineered abstractions
- functionality beyond acceptance criteria
- duplicated logic copied from nearby files but not adapted correctly
- fake or shallow tests
- tests that assert mocks instead of behavior
- inconsistent naming
- unused helper methods
- hallucinated APIs or config keys
- comments that do not match the code
- broad refactors unrelated to the story

## Java Standards

Check for:

- null safety
- appropriate exception handling
- immutable data where appropriate
- no unsafe casts
- no data loss from numeric conversion
- meaningful validation
- clean package placement
- service/controller separation
- no business logic in controllers
- no unnecessary static utility abuse
- no parameter mutation unless intentional and documented
- Java version compatibility for the repository

## Spring Boot Standards

Check for:

- thin controllers
- validation annotations on DTOs
- meaningful error responses
- service layer owns business logic
- repository/DAO layer owns data access
- dependency injection is clear
- bean ambiguity handled with qualifiers
- no hidden circular dependencies
- transaction boundaries are appropriate
- configuration defaults are safe

## React Standards

Check for:

- functional components and hooks used appropriately
- hooks dependency arrays are correct
- loading/error/empty states are handled
- no production console logs
- no direct DOM manipulation unless justified
- no unnecessary prop drilling
- state management is understandable
- components remain focused
- user-visible copy matches requirements
- accessibility basics are considered

## REST Standards

Check:

- resource naming is consistent
- HTTP methods match intent
- status codes are meaningful
- errors follow existing format
- validation is performed at the boundary
- versioning is clear
- backward compatibility is preserved
- response DTOs do not expose internal fields

## Documentation Standards

Require documentation for:

- new APIs
- protocol versions
- feature toggles
- config changes
- complex business logic
- intentional duplication
- non-obvious design decisions
- migration steps
- new dependencies

Avoid comments that only reference ticket numbers.

Comments should explain technical intent and behavior.
