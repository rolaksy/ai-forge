# Protocol, TDD, SCP, and KP-MAP Review

Use this reference when the PR touches protocol implementation, message definitions, SCP files, simulator behavior, TCP/XML integration, or KP-MAP legacy code.

## When Protocol/TDD Review Is Mandatory

Perform protocol/TDD review when the PR mentions or changes anything related to:

- protocol
- message
- SCP
- `*.scp`
- BHS
- FOSBER
- BOBST
- APCS
- PCS
- RSC
- Wet End
- station
- simulator
- LinkSimulator
- LinkDeviceSimulator
- KP-MAP
- message framing
- XML serialization
- TCP integration
- file transfer
- external system integration

## Document Search Order

Search for protocol/TDD documents in this order:

1. parent feature attachments and links
2. current work item attachments and links
3. child work items
4. spike/research work items
5. PR description links
6. internal documentation search
7. repository documentation

## Protocol Document Checks

Review protocol documents for:

- protocol version
- message structure
- field order
- field names
- object IDs
- field types
- field lengths
- required fields
- optional fields
- scale factors
- conversion rules
- default values
- request/response flow
- routing rules
- reply triggers
- error messages
- retry behavior
- timeout behavior
- backward compatibility

## TDD Checks

Review TDDs for:

- intended architecture
- component responsibilities
- data flow
- API contracts
- protocol version strategy
- database/storage design
- configuration approach
- error handling strategy
- test strategy
- deployment or migration notes
- known constraints
- design decisions

Compare implementation against the TDD.

Flag deviations unless clearly justified.

## SCP File Review

If any `*.scp` file is changed or mentioned:

- inspect the changed SCP file
- inspect related message routing files
- search KP-MAP for corresponding protocol/message definitions
- compare mappings with protocol requirements
- validate routing and action behavior

Check:

- object mappings such as `|id:XXXX|`
- `func:` directives
- `filter:` conditions
- `scale:SCALEL`
- `scale:SCALEW`
- `conv:` conversions
- `type:` definitions
- `action:` routing
- `applsend:` triggers
- conditional compilation with `#ifdef` / `#ifndef`
- protocol version routing
- backward compatibility
- field order
- required fields
- optional fields
- measurement scaling
- message reply behavior

## KP-MAP / Fortran Review

For KP-MAP Fortran or C changes, check:

- subroutine behavior matches acceptance criteria
- parameters match existing patterns
- variable declarations are correct
- common block usage is correct
- include files are correct
- file/database open and close sequence is safe
- define word handling is correct
- timestamps and Julian seconds are handled correctly
- character/integer conversion is safe
- debug logging is appropriate
- error handling is meaningful
- loops terminate correctly
- multi-message patterns are correct
- no unintended behavior change in legacy paths

## Action Routing Checks

When new action types or message handlers are added, verify:

- action routing files are updated
- action type max parameter is updated where required
- handlers call the correct subroutines
- version-specific actions route correctly
- request/reply behavior is wired correctly
- backward compatibility is preserved

## Measurement and Data Accuracy Checks

For measurement fields, check:

- length fields use correct scaling
- width fields use correct scaling
- unit conversion is correct
- numeric precision is not lost
- no unsafe long-to-int cast
- zero and negative values are handled if possible
- field type can hold expected values

## XML / Message Framing Checks

For XML/TCP protocol implementations, check:

- XML element names match the protocol
- JAXB annotations are correct
- custom mappers are used where required
- optional fields serialize correctly
- required fields are present
- message framing matches protocol
- STX/ETX or equivalent markers are correct
- counters are formatted correctly
- parsing errors are handled
- malformed messages do not crash the service

## Missing Document Limitation

If expected protocol or TDD documents cannot be accessed, include:

```text
⚠️ Limitation: Protocol/TDD compliance could not be fully verified because [document/link/source] was not accessible.
```

Also list:

- documents searched for
- where they were searched
- what could not be verified
- whether the review is partial
