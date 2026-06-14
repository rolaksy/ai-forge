# PR Description: WI-928017 — XMGEN Modern: Add More Logging to Link Device Simulator (NLA)

**ADO Work Item:** [928017](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/928017)  
**Repository:** KP-Xmit-LinkDeviceSimulator  
**Author:** Laks Yalamati  
**Date:** March 2026

---

## Summary

This PR adds comprehensive structured logging to the Link Device Simulator to improve troubleshooting, message traceability, and performance monitoring. The implementation mirrors the logging behaviour of `xmgen`, adds request-scoped correlation IDs, and introduces dedicated log files for protocol operations, connection lifecycle, and performance metrics.

All changes are backward-compatible. New log files are off by default or guarded by feature flags in `application.properties`.

---

## Problem Statement

The Link Device Simulator previously had minimal, inconsistent logging. When protocol issues occurred in production or QA environments, troubleshooting required attaching a debugger or adding ad-hoc log statements. There was no way to:

- Correlate a single request across encode/decode/service layers
- Quickly identify slow protocol operations
- Observe TCP connection lifecycle events
- Inspect the raw bytes being transmitted/received (hex dumps)

---

## What Was Changed

### 1. Log4j2 Configuration (`src/main/resources/log4j2-spring.xml`)

- Updated the main log pattern to include `%X{requestId}` via `%notEmpty{ [%X{requestId}]}`. When a request is active, every log line on that thread automatically carries `[req-<id>]`. Lines outside a request context are unaffected.
- Added 4 new **RollingFile appenders**:

  | Appender | File | Purpose |
  |---|---|---|
  | `ENCODE_DECODE_APPENDER` | `encode-decode.log.txt` | Protocol encode/decode steps |
  | `CONNECTION_APPENDER` | `connection.log.txt` | TCP connect/disconnect events |
  | `PERFORMANCE_APPENDER` | `performance.log.txt` | Slow-request performance data |
  | Existing main/error appenders | _(retained)_ | General application output |

- Added dedicated logger configurations for `com.kiwiplan.protocol`, `com.kiwiplan.tcp`, `com.kiwiplan.udp`, `com.kiwiplan.service`, and `com.kiwiplan.performance`.

---

### 2. Application Properties (`src/main/resources/application.properties`)

Added the following feature flags. All can be toggled without a code change or rebuild:

```properties
# Encode/decode operation logging
logging.encode-decode.enabled=true
logging.encode-decode.level=info

# TCP/UDP connection event logging
logging.connection.enabled=true
logging.connection.level=info

# Performance threshold — operations slower than this are flagged
logging.performance.enabled=true
logging.performance.threshold-ms=100

# Hex dump logging (off by default; enable for byte-level troubleshooting)
logging.hex.enabled=false
```

---

### 3. New Utility Classes

#### `RequestIdGenerator` (`src/main/java/com/kiwiplan/util/RequestIdGenerator.java`)

Generates short, unique, human-readable correlation IDs for each request:

```
req-1709734821456-0042
     ^timestamp   ^sequence (4-digit, wraps at 10000)
```

These IDs are injected into SLF4J MDC at the start of each request and cleared afterwards. Every log line emitted on that thread while processing the request automatically includes the ID.

#### `ProtocolLogger` (`src/main/java/com/kiwiplan/util/ProtocolLogger.java`)

A Spring-managed logger dedicated to protocol operations. Provides structured log methods:

- `logDecodeStart / logDecodeEnd / logDecodeError` — decode timing and outcome
- `logEncodeStart / logEncodeEnd / logEncodeError` — encode timing and outcome
- `logPayloadShape` — field-name/type summary (no raw values; safe for production)
- `logRawPayload` — full payload content (DEBUG level only)
- `logHexDump(direction, protocolName, data)` — RX/TX hex dump in xmgen format (see below)

#### `PayloadShapeExtractor` (`src/main/java/com/kiwiplan/util/PayloadShapeExtractor.java`)

Uses reflection to extract field names and types from protocol payload objects, so the payload *shape* can be logged at INFO level without exposing field values.

#### `ConnectionEventLogger` (`src/main/java/com/kiwiplan/tcp/ConnectionEventLogger.java`)

A Spring Integration `TcpConnectionEventListenerAdapter` that logs TCP connect, disconnect, and exception events at INFO level to the dedicated connection log.

---

### 4. AOP Service Logging Aspect (`src/main/java/com/kiwiplan/aspect/ServiceLoggingAspect.java`)

The most impactful architectural change. A Spring AOP aspect intercepts **all** `SimulatorService.processRequest()` calls automatically — no changes required in individual service classes.

**What the aspect does:**

- `@Around` advice:
  1. Generates a `requestId` and puts it in SLF4J MDC.
  2. Logs `REQUEST_START` with protocol name and input size.
  3. Invokes the real service method.
  4. Logs `REQUEST_END` with duration (ms).
  5. Clears MDC in `finally` (always runs — prevents MDC leaks).

- `@AfterThrowing` advice (separate):
  - Logs `REQUEST_ERROR` with the exception message and full stack trace.
  - Does **not** catch or rethrow — compliant with SonarQube rule **java:S2139** (exceptions must not be both logged and rethrown from the same method).

**Result:** All 50+ `SimulatorService` implementations gain structured lifecycle logging with zero per-class changes.

Example log output for a successful request:

```
2026-03-04 14:22:01 INFO  ServiceLoggingAspect [req-1709734821456-0042] - REQUEST_START service=FosberLinkV4225tService inputSize=84
2026-03-04 14:22:01 INFO  FosberLinkV4225tService [req-1709734821456-0042] - REQUEST_DECODED messageType=LineSynchronisation
2026-03-04 14:22:01 INFO  ServiceLoggingAspect [req-1709734821456-0042] - REQUEST_END service=FosberLinkV4225tService duration=3ms
```

Example log output for a failed request:

```
2026-03-04 14:22:05 ERROR ServiceLoggingAspect [req-1709734821456-0043] - REQUEST_ERROR service=FosberLinkV4225tService error=Unexpected message type
    at com.kiwiplan.service.fosber...
```

---

### 5. Protocol Layer Hex Dump (`src/main/java/com/kiwiplan/protocol/AbstractStringProtocol.java`)

When `logging.hex.enabled=true` and the logger is at DEBUG level, `AbstractStringProtocol` now calls `protocolLogger.logHexDump()` at two points:

- **RX** — immediately on decode entry (raw inbound bytes)
- **TX** — immediately after encode completes (raw outbound bytes)

The format matches the xmgen hex log output: 16 bytes per row, offset column, hex column, and printable-ASCII column. Non-printable bytes appear as `.`.

Example output:

```
2026-03-04 14:22:01 DEBUG ProtocolLogger [req-1709734821456-0042] - HEX_DUMP direction=RX protocol=FosberLinkV4225t length=20
  0000  02 4c 53 59 4e 43 20 20  20 42 42 31 30 30 31 03  .LSYNC   BB1001.
  0010  0d 0a 00 00                                        ....
```

Byte encoding uses ISO-8859-1 to preserve 8-bit protocol control bytes (STX=`0x02`, ETX=`0x03`, CR=`0x0D`).

This feature is **disabled by default** (`logging.hex.enabled=false`). It is intended for byte-level troubleshooting and should remain off in production unless actively investigating a protocol issue.

---

### 6. TCP Connection Manager (`src/main/java/com/kiwiplan/tcp/client/TcpConnectionManager.java`)

Added connection lifecycle logging via `ConnectionEventLogger`: connect, disconnect, and exception events are now recorded at INFO level with timestamp, host, port, and connection ID.

---

### 7. `pom.xml`

Added the `spring-boot-starter-aop` dependency to enable Spring AOP support for the `ServiceLoggingAspect`.

---

## Files Changed

| File | Type | Description |
|---|---|---|
| `src/main/resources/log4j2-spring.xml` | Modified | New appenders, logger configs, updated pattern |
| `src/main/resources/application.properties` | Modified | New logging feature-flag properties |
| `pom.xml` | Modified | Added `spring-boot-starter-aop` |
| `src/main/java/com/kiwiplan/aspect/ServiceLoggingAspect.java` | New | AOP aspect — centralises service lifecycle logging |
| `src/main/java/com/kiwiplan/util/RequestIdGenerator.java` | New | Correlation ID generation |
| `src/main/java/com/kiwiplan/util/ProtocolLogger.java` | New | Structured protocol logger with hex dump support |
| `src/main/java/com/kiwiplan/util/PayloadShapeExtractor.java` | New | Reflection-based payload shape extraction |
| `src/main/java/com/kiwiplan/tcp/ConnectionEventLogger.java` | New | TCP connection event listener/logger |
| `src/main/java/com/kiwiplan/protocol/AbstractStringProtocol.java` | Modified | Hex dump calls added to decode/encode |
| `src/main/java/com/kiwiplan/tcp/client/TcpConnectionManager.java` | Modified | Connection lifecycle logging |
| `src/main/java/com/kiwiplan/service/fosber/dryend/FosberLinkV4225tService.java` | Modified | Simplified — lifecycle logging moved to aspect |
| `src/test/java/com/kiwiplan/util/PayloadShapeExtractorTest.java` | New | 7 unit tests |
| `src/test/java/com/kiwiplan/util/ProtocolLoggerTest.java` | New | 14 unit tests |
| `src/test/java/com/kiwiplan/util/RequestIdGeneratorTest.java` | New | 1 unit test |

---

## Testing

- All **26 unit tests** pass (`mvn clean install`).
- No existing tests were modified.
- New tests cover: payload shape extraction edge cases, protocol logger method contracts, and request ID format/uniqueness.

---

## How to Enable Verbose Logging for Troubleshooting

Add the following to `application.properties` (or override at runtime via environment variables):

```properties
# Enable hex dumps
logging.hex.enabled=true

# Set protocol logger to DEBUG to see hex/raw payloads
logging.level.com.kiwiplan.protocol=DEBUG

# Set service layer to DEBUG to see routing decisions
logging.level.com.kiwiplan.service=DEBUG
```

Leave all other settings at their defaults for normal production operation.

---

## Acceptance Criteria Verification

| Criterion | Status |
|---|---|
| Default production log level is `info`; `debug/trace` is feature-flagged | ✅ |
| Handshake / connect / disconnect events logged at `info` | ✅ |
| Encode/decode steps log: start, end, duration, payload shape only | ✅ |
| Similar hex logging to xmgen (configurable on/off) | ✅ |
| Dedicated encode/decode log file | ✅ |
| Request correlation IDs visible across all log lines for a single request | ✅ |
| No code changes required in individual service classes | ✅ (AOP aspect) |
| SonarQube S2139 compliant — no log+rethrow in same method | ✅ |

---

## Notes / Follow-up

- The `ServiceLoggingAspect` covers all current and future `SimulatorService` implementations automatically — no per-service changes are needed as new protocols are added.
- The same logging pattern (`ProtocolLogger`, `ServiceLoggingAspect`, hex dump) should be applied to **Link Device** and **Link Central** repositories as follow-up work per WI-928017 scope.
- `logging.hex.enabled` should remain `false` in all deployed environments unless actively investigating a protocol byte-level issue.
