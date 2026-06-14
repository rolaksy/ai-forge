# Repository-Specific PR Review Patterns

Apply these checks when the repository is known.

## KP-Xmit-LinkDeviceSimulator

Focus on:

- protocol implementation correctness
- message framing
- XML serialization/deserialization
- TCP communication patterns
- service factory patterns
- Spring bean management
- protocol version documentation
- test coverage for protocol message handling
- JAXB annotations
- MapStruct patterns

Critical checks:

- protocol version is documented in JavaDoc
- message framing matches specification
- no mutation of input parameters unless explicitly documented
- all protocol fields are represented in DTO and test data
- XML structure matches protocol specification
- Spring beans use qualifiers where needed
- service factory routes to correct protocol service
- optional fields are handled correctly
- invalid messages are handled gracefully

Common issues:

- missing protocol version documentation
- incomplete protocol test data
- input parameter mutation
- missing JAXB annotations
- missing service factory registration
- NoUniqueBeanDefinitionException risk
- weak message framing tests

## KP-Xmit-LinkSimulator

Focus on:

- API endpoint documentation
- API versioning
- frontend-backend integration
- React component quality
- DTO validation
- error handling in UI code
- console logging

Critical checks:

- no production `console.log` or `console.error`
- API versions are clearly documented
- DTO fields match frontend/backend expectations
- validation annotations exist for required fields
- UI handles loading, empty, and error states
- frontend API error handling is user-friendly
- merge conflict markers are absent

Common issues:

- unclear endpoint version differences
- missing JavaDoc for new APIs
- leftover console logs
- missing DTO validation
- frontend/backend field mismatch
- weak React tests

## KP-Xmit-LinkCentral

Focus on:

- PCS API integration
- multi-station vs single-station behavior
- service layer responsibilities
- DAO null safety
- SQL correctness
- API documentation
- data type safety

Critical checks:

- null checks before object/property access
- no unsafe numeric casts
- SQL aggregation uses explicit separators where needed
- endpoint versions are documented
- service layer owns business logic
- DAO queries are safe and efficient
- error handling includes useful context

Common issues:

- missing null checks
- long-to-int cast without validation
- undocumented duplicate getters
- unclear JSON serialization behavior
- missing API version usage guidance
- SQL behavior relying on database defaults

## KP-Xmit-LinkDevice

Focus on:

- controller/service separation
- unit conversion logic
- feature toggle behavior
- dependency management
- merge conflict resolution
- service layer architecture
- mapper/utility class design

Critical checks:

- controllers do not contain conversion/business logic
- conversion logic is isolated in mapper/utility classes
- feature toggle behavior is documented
- config defaults are safe
- no leftover conflict markers
- dependencies are justified and compatible with related products

Common issues:

- single responsibility violations
- undocumented feature toggles
- conversion logic mixed into controllers
- dependency duplication
- incomplete merge conflict resolution

## KP-MAP

Focus on:

- legacy Fortran/C integration
- SCP message definitions
- action routing
- data validation
- edge cases
- database/file operation order
- required field handling

Critical checks:

- zero and negative values are handled
- required fields are validated
- action type max parameters are updated when new actions are added
- version-specific routing is correct
- measurement scaling is correct
- object IDs match protocol expectations
- file open/close patterns match existing code
- data conversions are safe

Common issues:

- missing edge case handling
- incomplete required field validation
- incorrect measurement scaling
- missing action routing updates
- unsafe legacy data assumptions
- missing error handling

## KP-MapJava

Focus on:

- method complexity
- maintainability
- business logic decomposition
- Java version compatibility
- refactoring safety

Critical checks:

- avoid very large or high-complexity methods
- reduce deep nesting
- preserve behavior during refactoring
- tests cover refactored logic
- Java 11 compatibility is preserved where required
- business rules are not mixed with infrastructure code

Common issues:

- methods doing too much
- excessive branching
- hard-to-read business logic
- missing tests after refactor
- newer Java syntax used in Java 11 modules

## Shared Java Libraries

Focus on:

- backward compatibility
- public API impact
- dependency impact
- semantic behavior changes
- downstream consumers

Critical checks:

- public APIs are not broken unexpectedly
- behavior changes are documented
- dependencies are compatible
- tests cover existing behavior
- downstream impact is considered

## React Frontends

Focus on:

- user-visible behavior
- state management
- API integration
- validation
- error handling
- accessibility basics
- test coverage

Critical checks:

- no production console logs
- no broken loading/error states
- API errors handled gracefully
- UI copy matches requirements
- components clean up effects
- no stale or missing dependencies in hooks
