# Work Item 928017: XMGEN Modern - Add More Logging to NLA
## Implementation Plan: Link Device Repository

**Date**: March 6, 2026  
**Developer**: Laks Yalamati  
**Repository**: KP-Xmit-LinkDevice  
**ADO**: https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/928017  
**Status**: Approved — Ready for Implementation

---

## Decisions from Review

| # | Question | Decision |
|---|----------|----------|
| 1 | Config file location | `linkdevice.yml` only |
| 2 | Encode/decode helpers location | `GeneralControllerService` (clean approach, covers all controllers) |
| 3 | `ByteArrayTcpClientImpl` TCP logging | Yes — include |
| 4 | `MappingLinkCentralClient` | Not needed — `BaseWebClient`/AOP covers it |
| 5 | AOP | Use Spring AOP where possible |

**Log files required**: encode-decode, api-calls, connection only (no performance log file).

---

## 1. Executive Summary

This plan extends the logging work already completed for the **Link Device Simulator** (ADO 928017) to the **Link Device** repository. The two repositories serve different purposes, meaning the logging design must be adapted to fit the Link Device's specific data flow.

### Key Difference from Simulator

| Aspect | Link Device Simulator | Link Device |
|----|----|----|
| Data source | Gets data from xmgen via TCP | Gets lineup from **Link Central via REST API** |
| Data target | Sends data to Link Simulator via REST | Sends encoded data to **physical controller via TCP** |
| Encode/Decode | Protocol-level abstraction (`AbstractStringProtocol`) | Per-method encode/decode in controller service |
| Connection mgmt | Spring Integration TCP server | Spring Integration TCP client (outbound) |
| Cycle | Event-driven (inbound message) | Scheduled polling cycle |

---

## 2. Data Flow & Logging Scope

The full request/response lifecycle in Link Device is:

```
[Scheduler Tick]
     │
     ▼
GeneralLinkService.controllerTasks()
     │
     ├──► controllerService.updateMachineLineup()
     │         └──► TCP → encodeWithLogging(LineupReqDto) → controller → decodeWithLogging(LineupResDto)
     │
     ├──► controllerService.updateHistoryData()
     │         └──► TCP → encodeWithLogging(HistoryReqDto) → controller → decodeWithLogging(HistoryResDto)
     │
     ├──► controllerService.updateCurrentRunData()
     │         └──► TCP → encodeWithLogging(CurrentRunReqDto) → controller → decodeWithLogging(CurrentRunResDto)
     │
     ├──► updateControllerLineup()
     │         ├──► REST GET  → Link Central (getLineupEntries) ← AOP intercepts here
     │         └──► TCP → encodeWithLogging(LineupItemAddReqDto) → controller → ACK/NACK
     │
     ├──► processCurrentRunData()
     │         └──► REST POST → Link Central (updateJobProgress) ← AOP intercepts here
     │
     └──► processHistoryData()
               └──► REST POST → Link Central (finishJob) ← AOP intercepts here
```

### Layers requiring logging

| Layer | Class(es) | Approach | Log File |
|-------|-----------|----------|----------|
| **Link Central API** | `LinkCentralClientImpl` | Spring AOP (`LinkCentralApiLoggingAspect`) | `api-calls.log.txt` |
| **Encode/Decode** | `GeneralControllerService` (protected helpers) | Direct structured logging | `encode-decode.log.txt` |
| **TCP Connection/Send** | `StringTcpClientImpl`, `ByteArrayTcpClientImpl` | Direct structured logging | `connection.log.txt` |

---

## 3. Acceptance Criteria

- ✅ Default production level is `INFO`; `DEBUG/TRACE` is flag-controlled
- ✅ Handshake/connect/disconnect events log at `INFO`
- ✅ Encode/decode steps log: start, end, duration; payload **shape only** (no raw values)
- ✅ Similar structured logging to xmgen
- ✅ Dedicated log files per concern

---

## 4. AOP Strategy & Constraints

### Why AOP Only Applies to the API Layer

Spring AOP works only on Spring-managed beans (proxy-based). Scanning the codebase:

| Class | Spring Bean? | AOP Possible? |
|-------|-------------|---------------|
| `LinkCentralClientImpl` | ✅ Yes (`@Bean` in `WebClientConfiguration`) | ✅ Yes |
| `MappingLinkCentralClient` | ❌ No (created via `new` in `FieldMappingClientFactory`) | ❌ No — but delegates to `LinkCentralClientImpl` which IS a bean, so the delegate call IS intercepted |
| `GopfertPlantFloorMachineTCPControllerService` | ❌ No (created via `new` in `ControllerServiceFactory`) | ❌ No |
| `StringTcpClientImpl` | ❌ No (created via builder `.build()`) | ❌ No |
| `ByteArrayTcpClientImpl` | ❌ No (created via builder `.build()`) | ❌ No |

### `LinkCentralApiLoggingAspect`

**Pointcut**: `execution(* com.kiwiplan.linkdevice.config.client.LinkCentralClient.*(..))`

This intercepts all three API call methods (`getLineupEntries`, `updateJobProgress`, `finishJob`) when called through the Spring proxy on `LinkCentralClientImpl`. This covers:
- Direct injection path (`LinkCentralClientImpl` injected straight into link service)
- Mapping path (`MappingLinkCentralClient.delegate` = Spring proxy of `LinkCentralClientImpl`)

No double-logging risk because `MappingLinkCentralClient` itself is not proxied.

**Advice**: `@Around` — captures duration, method name, arguments shape, return shape (at DEBUG).

```java
@Aspect
@Component
public class LinkCentralApiLoggingAspect {

    private static final Logger apiLog = LoggerFactory.getLogger("com.kiwiplan.linkdevice.apicalls");

    @Around("execution(* com.kiwiplan.linkdevice.config.client.LinkCentralClient.*(..))")
    public Object logApiCall(ProceedingJoinPoint pjp) throws Throwable {
        String methodName = pjp.getSignature().getName();
        long start = System.currentTimeMillis();
        apiLog.info("API_CALL_START method={}", methodName);
        try {
            Object result = pjp.proceed();
            long duration = System.currentTimeMillis() - start;
            apiLog.info("API_CALL_END method={} duration={}ms", methodName, duration);
            if (apiLog.isDebugEnabled()) {
                apiLog.debug("API_CALL_SHAPE method={} response_shape={}", methodName,
                             PayloadShapeExtractor.extract(result));
            }
            return result;
        } catch (Throwable t) {
            apiLog.error("API_CALL_ERROR method={} duration={}ms error={}",
                         methodName, System.currentTimeMillis() - start, t.getMessage());
            throw t;
        }
    }
}
```

---

## 5. Phase-by-Phase Implementation Plan

---

### Phase 1: Infrastructure Setup

#### 1.1 log4j2-spring.xml — New Appenders & Loggers

**File**: `linkdevice-app/src/main/resources/log4j2-spring.xml`

Add 3 new rolling file appenders:

| Appender | File | Size | Retention |
|----------|------|------|-----------|
| `ENCODE_DECODE_APPENDER` | `encode-decode.log.txt` | 10MB | 90 days |
| `API_CALLS_APPENDER` | `api-calls.log.txt` | 10MB | 90 days |
| `CONNECTION_APPENDER` | `connection.log.txt` | 10MB | 90 days |

Add named loggers that route to dedicated files:

```xml
<Logger name="com.kiwiplan.linkdevice.encodedecode" level="INFO" additivity="false">
    <AppenderRef ref="ENCODE_DECODE_APPENDER"/>
    <AppenderRef ref="FILE_APPENDER"/>
    <AppenderRef ref="ERROR_APPENDER"/>
</Logger>

<Logger name="com.kiwiplan.linkdevice.apicalls" level="INFO" additivity="false">
    <AppenderRef ref="API_CALLS_APPENDER"/>
    <AppenderRef ref="FILE_APPENDER"/>
    <AppenderRef ref="ERROR_APPENDER"/>
</Logger>

<Logger name="com.kiwiplan.linkdevice.connection" level="INFO" additivity="false">
    <AppenderRef ref="CONNECTION_APPENDER"/>
    <AppenderRef ref="FILE_APPENDER"/>
    <AppenderRef ref="ERROR_APPENDER"/>
</Logger>
```

#### 1.2 linkdevice.yml — Logging Config

Add to `linkdevice.yml`:

```yaml
logging:
  level:
    com.kiwiplan.linkdevice.encodedecode: INFO
    com.kiwiplan.linkdevice.apicalls: INFO
    com.kiwiplan.linkdevice.connection: INFO
  hex:
    enabled: false   # Set to true to emit xmgen-style hex dumps in encode-decode.log.txt
```

> **Note**: `logging.hex.enabled=false` default means no hex dump output in production. Set to `true` in dev/QA `linkdevice-dev.yml` or at runtime to enable. Mirrors the simulator's `logging.hex.enabled` flag.

---

### Phase 2: New Utility Class — `PayloadShapeExtractor`

**Package**: `com.kiwiplan.linkdevice.logging`  
**File**: `src/main/java/com/kiwiplan/linkdevice/logging/PayloadShapeExtractor.java`

Reused from simulator implementation. Extracts field names + types (not values) from any object via reflection. Used at DEBUG level in all three layers.

```java
// Example output: {"jobId":"String[6]","width":"Integer","length":"Integer"}
String shape = PayloadShapeExtractor.extract(lineupItemAddReqDto);
```

Features: null-safe, depth-limited (2 levels), handles primitives/collections/maps/POJOs, no sensitive value exposure.

---

### Phase 3: Encode/Decode Logging — `GeneralControllerService`

**File**: `linkdevice-app/src/main/java/com/kiwiplan/linkdevice/controller/GeneralControllerService.java`

#### 3.1 Hex Dump Config — `LinkDeviceLoggingConfig`

Because `GopfertPlantFloorMachineTCPControllerService` and all controller services are non-Spring-managed objects (created via `new` in `ControllerServiceFactory`), they cannot use `@Value` injection. The standard Spring pattern for non-bean objects is a **static-field initializer component**:

**File**: `src/main/java/com/kiwiplan/linkdevice/logging/LinkDeviceLoggingConfig.java`

```java
package com.kiwiplan.linkdevice.logging;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Spring component that exposes logging feature-flags as static fields so
 * non-Spring-managed objects (controller services, TCP clients) can read them
 * after the application context has started.
 */
@Component
public class LinkDeviceLoggingConfig {

    private static boolean hexEnabled = false;

    @Value("${logging.hex.enabled:false}")
    public void setHexEnabled(boolean value) {
        LinkDeviceLoggingConfig.hexEnabled = value;
    }

    public static boolean isHexEnabled() {
        return hexEnabled;
    }
}
```

This is initialized once at startup. All controller services then call `LinkDeviceLoggingConfig.isHexEnabled()`.

> **Config entry** (in `linkdevice.yml`, under the new logging block):
> ```yaml
> logging:
>   hex:
>     enabled: false
> ```

#### 3.2 Hex Dump Format

The format mirrors the simulator's `ProtocolLogger.logHexDump()` exactly: 16 bytes per row, ASCII column (left), 1-based offset, hex column (right). The encoded String is converted to bytes via `ISO_8859_1` (same as simulator) to preserve control characters unchanged. A private static helper method is added to `GeneralControllerService`:

```java
private static String formatHexDump(String direction, String protocolName, String data) {
    byte[] bytes = data.getBytes(StandardCharsets.ISO_8859_1);
    StringBuilder sb = new StringBuilder();
    sb.append(String.format("HEX_DUMP direction=%s protocol=%s size=%d bytes%n",
            direction, protocolName, bytes.length));
    for (int offset = 0; offset < bytes.length; offset += 16) {
        int rowLen = Math.min(16, bytes.length - offset);
        StringBuilder ascii = new StringBuilder();
        for (int i = 0; i < rowLen; i++) {
            byte b = bytes[offset + i];
            ascii.append((b >= 0x20 && b < 0x7F) ? (char) b : '.');
        }
        for (int i = rowLen; i < 16; i++) ascii.append(' ');
        StringBuilder hex = new StringBuilder();
        for (int i = 0; i < rowLen; i++) hex.append(String.format("%02X ", bytes[offset + i]));
        sb.append(String.format("%-16s  %4d   %s  %d",
                ascii, offset + 1, hex, offset + rowLen));
        if (offset + 16 < bytes.length) sb.append(System.lineSeparator());
    }
    return sb.toString();
}
```

#### 3.3 Updated `encodeWithLogging` / `decodeWithLogging`

Add a dedicated named logger + two protected helper methods with hex dump support. Hex dump is gated by both `hexEnabled` flag **and** INFO level, so it appears in `encode-decode.log.txt` in the same way the simulator's `ProtocolLogger` records it (at INFO when the flag is on).

```java
private static final Logger encodeDecodeLog =
        LoggerFactory.getLogger("com.kiwiplan.linkdevice.encodedecode");

protected <T> String encodeWithLogging(Message<T> messageBuilder, Object dto, String protocolName) {
    String messageType = dto.getClass().getSimpleName();
    long start = System.currentTimeMillis();
    encodeDecodeLog.info("ENCODE_START messageType={}", messageType);
    String encoded = messageBuilder.encode(dto);
    long duration = System.currentTimeMillis() - start;
    encodeDecodeLog.info("ENCODE_END messageType={} duration={}ms payloadSize={} bytes",
                         messageType, duration, encoded.length());
    if (encodeDecodeLog.isDebugEnabled()) {
        encodeDecodeLog.debug("ENCODE_SHAPE messageType={} shape={}",
                              messageType, PayloadShapeExtractor.extract(dto));
    }
    if (encodeDecodeLog.isTraceEnabled()) {
        encodeDecodeLog.trace("ENCODE_PAYLOAD messageType={} payload={}", messageType, encoded);
    }
    if (LinkDeviceLoggingConfig.isHexEnabled() && encodeDecodeLog.isInfoEnabled()) {
        encodeDecodeLog.info("{}", formatHexDump("TX", protocolName, encoded));
    }
    return encoded;
}

protected <T, R> R decodeWithLogging(Message<T> messageBuilder, String payload,
                                     Class<R> responseClass, String protocolName) {
    long start = System.currentTimeMillis();
    encodeDecodeLog.info("DECODE_START responseClass={} payloadSize={} bytes",
                         responseClass.getSimpleName(), payload.length());
    if (LinkDeviceLoggingConfig.isHexEnabled() && encodeDecodeLog.isInfoEnabled()) {
        encodeDecodeLog.info("{}", formatHexDump("RX", protocolName, payload));
    }
    R decoded = messageBuilder.decode(payload, responseClass);
    long duration = System.currentTimeMillis() - start;
    encodeDecodeLog.info("DECODE_END responseClass={} duration={}ms",
                         responseClass.getSimpleName(), duration);
    if (encodeDecodeLog.isDebugEnabled()) {
        encodeDecodeLog.debug("DECODE_SHAPE responseClass={} shape={}",
                              responseClass.getSimpleName(), PayloadShapeExtractor.extract(decoded));
    }
    if (encodeDecodeLog.isTraceEnabled()) {
        encodeDecodeLog.trace("DECODE_PAYLOAD responseClass={} payload={}",
                              responseClass.getSimpleName(), payload);
    }
    return decoded;
}
```

> **Signature change**: `protocolName` parameter added (e.g. `"Gopfert"`) so the hex dump header identifies the protocol, matching the simulator's format exactly.

> **Note**: `Message` interface uses generic type `T` for encoding and class-based decoding. The method signature takes `Message<T>` to remain type-safe. Concrete controllers pass their own `messageBuilder` field and a constant protocol name string.

> **Why not AOP?** `GopfertPlantFloorMachineTCPControllerService` is created via `new` in `ControllerServiceFactory` — not a Spring bean. Spring AOP proxy does not wrap it. Direct structured logging is the correct approach here.

---

### Phase 4: Update `GopfertPlantFloorMachineTCPControllerService`

**File**: `linkdevice-app/src/main/java/com/kiwiplan/linkdevice/controller/converter/gopfert/GopfertPlantFloorMachineTCPControllerService.java`

Replace all direct `messageBuilder.encode(...)` calls with `encodeWithLogging(messageBuilder, ..., "Gopfert")` and `messageBuilder.decode(...)` with `decodeWithLogging(messageBuilder, ..., LineupResDto.class, "Gopfert")`.

#### Methods to update

| Method | Change |
|--------|--------|
| `getLineup()` | encode + decode |
| `getHistoryStatistics()` | encode + decode |
| `getCurrentRunData()` | encode + decode |
| `sendLineupItemToController()` | encode only (response is ACK/NACK control char) |
| `rearrangeControllerLineup()` | encode only |
| `removeLineupItemFromController()` | encode only |
| `sendDebugMessage()` | encode + decode |

#### Handshake Logging Enhancement

Enhance `initiateCommunication()` and `terminateCommunication()` with timing and status:

```java
private void initiateCommunication() {
    long start = System.currentTimeMillis();
    log.info("HANDSHAKE_START type=ENQ controllerId={}", getControllerId());
    log.trace("Sending ENQ Control Character to the Controller.");
    String response = tcpClient.sendMessageSync(String.valueOf(ENQ));
    if (!isAckResponse(response)) {
        log.error("HANDSHAKE_FAILED type=ENQ controllerId={} duration={}ms",
                  getControllerId(), System.currentTimeMillis() - start);
        throw new ControllerRequestFailedException("Invalid Response from the Controller.");
    }
    log.info("HANDSHAKE_END type=ENQ controllerId={} duration={}ms status=ACK",
             getControllerId(), System.currentTimeMillis() - start);
}

private void terminateCommunication() {
    long start = System.currentTimeMillis();
    log.info("HANDSHAKE_START type=EOT controllerId={}", getControllerId());
    log.trace("Sending EOT Control Character to the Controller.");
    String response = tcpClient.sendMessageSync(String.valueOf(EOT));
    if (!isAckResponse(response)) {
        log.error("HANDSHAKE_FAILED type=EOT controllerId={} duration={}ms response={}",
                  getControllerId(), System.currentTimeMillis() - start, response);
    } else {
        log.info("HANDSHAKE_END type=EOT controllerId={} duration={}ms status=ACK",
                 getControllerId(), System.currentTimeMillis() - start);
    }
}
```

---

### Phase 5: TCP Connection Logging — `StringTcpClientImpl` & `ByteArrayTcpClientImpl`

Both files get a dedicated named logger. All lifecycle events route to `connection.log.txt`.

**For `StringTcpClientImpl`**:

```java
private static final Logger connectionLog = LoggerFactory.getLogger("com.kiwiplan.linkdevice.connection");
```

| Method | Changes |
|--------|---------|
| `connect()` | Log `TCP_CONNECT_START host=... port=... responseTimeout=...s connectTimeout=...s` before; log `TCP_CONNECT_SUCCESS duration=...ms` after |
| `disconnect()` | Log `TCP_DISCONNECT_START`; log `TCP_DISCONNECT_SUCCESS duration=...ms` after |
| `sendMessageSync()` | Log `TCP_SEND_START payloadSize=...` at INFO (promote from TRACE); log `TCP_SEND_END responseSize=... duration=...ms` at INFO; keep raw payload at TRACE only |

**For `ByteArrayTcpClientImpl`**: Identical structure — `connect()`, `disconnect()`, `sendMessageSync()` get the same INFO-level structured entries to `connectionLog`. The existing TRACE-level hex dump of raw bytes is kept as-is.

> **Why not AOP?** Both TCP client implementations are instantiated via `stringTcpClientBuilder.build()` and `byteArrayTcpClientBuilder.build()` — they are not Spring beans, so Spring AOP proxy does not apply.

---

### Phase 6: API Call Logging — AOP `LinkCentralApiLoggingAspect`

**File**: `src/main/java/com/kiwiplan/linkdevice/logging/LinkCentralApiLoggingAspect.java`

Full implementation as shown in Section 4 above. Routes all log output to `"com.kiwiplan.linkdevice.apicalls"` logger → `api-calls.log.txt`.

**AOP dependency**: Spring AOP is already available in Spring Boot. No additional dependency needed.

**Coverage**:
- `getLineupEntries()` — logs when pulling lineup from Link Central
- `updateJobProgress()` — logs when sending current run data to Link Central  
- `finishJob()` — logs when completing a job to Link Central

---

### Phase 7: Testing

#### Unit Tests

| Class | Test File | Tests |
|-------|-----------|-------|
| `PayloadShapeExtractor` | `PayloadShapeExtractorTest.java` | 6: null, String, Collection, Map, POJO, nested POJO |
| `LinkCentralApiLoggingAspect` | `LinkCentralApiLoggingAspectTest.java` | 4: success logs start/end, error logs error, DEBUG shape logged when enabled, shape not logged when DEBUG disabled |
| `LinkDeviceLoggingConfig` | `LinkDeviceLoggingConfigTest.java` | 2: `hexEnabled` defaults false; `setHexEnabled(true)` updates static field and `isHexEnabled()` returns true |

> Test `LinkCentralApiLoggingAspect` with a Spring context (`@SpringBootTest` or `@ExtendWith(SpringExtension.class)`) using a mock `LinkCentralClient` bean to verify aspect fires.

---

## 6. Revised Files List

### Configuration (2 files)
1. ✏️ `src/main/resources/log4j2-spring.xml` — 3 new appenders + 3 named loggers
2. ✏️ `src/main/resources/linkdevice.yml` — logging level config

### Source: Modified (4 files)
3. ✏️ `src/main/java/com/kiwiplan/linkdevice/controller/GeneralControllerService.java` — add `encodeWithLogging()` + `decodeWithLogging()` protected methods + `encodeDecodeLog` named logger
4. ✏️ `src/main/java/com/kiwiplan/linkdevice/controller/converter/gopfert/GopfertPlantFloorMachineTCPControllerService.java` — replace encode/decode calls + handshake logging
5. ✏️ `src/main/java/com/kiwiplan/linkdevice/communication/tcp/client/StringTcpClientImpl.java` — connection + send structured logging
6. ✏️ `src/main/java/com/kiwiplan/linkdevice/communication/tcp/client/ByteArrayTcpClientImpl.java` — connection + send structured logging

### Source: New (4 files)
7. ✨ `src/main/java/com/kiwiplan/linkdevice/logging/PayloadShapeExtractor.java` — payload shape utility
8. ✨ `src/main/java/com/kiwiplan/linkdevice/logging/LinkCentralApiLoggingAspect.java` — Spring AOP for API calls
9. ✨ `src/main/java/com/kiwiplan/linkdevice/logging/LinkDeviceLoggingConfig.java` — static-field initializer for non-bean access to `logging.hex.enabled`

### Tests: New (3 files)
10. ✨ `src/test/java/com/kiwiplan/linkdevice/logging/PayloadShapeExtractorTest.java`
11. ✨ `src/test/java/com/kiwiplan/linkdevice/logging/LinkCentralApiLoggingAspectTest.java`
12. ✨ `src/test/java/com/kiwiplan/linkdevice/logging/LinkDeviceLoggingConfigTest.java`

**Total: 12 files** (2 config, 4 modified source, 3 new source, 3 new tests)

---

## 7. Log File Structure

```
${ROOT_DIR}/NLALogs/linkdevice/
├── linkdevice.log.txt              # Main application log (existing) — all INFO+ from all 3 new loggers also mirrors here
├── linkdevice-error.log.txt        # Error log WARN+ (existing)
├── encode-decode.log.txt           # Protocol encode/decode (NEW)
├── api-calls.log.txt               # Link Central REST API calls (NEW)
├── connection.log.txt              # TCP connect/disconnect/send (NEW)
└── archive/
    ├── linkdevice-*.log.gz
    ├── encode-decode-*.log.gz
    ├── api-calls-*.log.gz
    └── connection-*.log.gz
```

---

## 8. Sample Log Output

### INFO Level (Production Default)

**encode-decode.log.txt**:
```
2026-03-06 10:15:23 INFO  linkdevice.encodedecode - ENCODE_START messageType=LineupReqDto
2026-03-06 10:15:23 INFO  linkdevice.encodedecode - ENCODE_END messageType=LineupReqDto duration=2ms payloadSize=12 bytes
2026-03-06 10:15:23 INFO  GopfertPlantFloor...    - HANDSHAKE_START type=ENQ controllerId=GOPFERT_1
2026-03-06 10:15:23 INFO  GopfertPlantFloor...    - HANDSHAKE_END type=ENQ controllerId=GOPFERT_1 duration=32ms status=ACK
2026-03-06 10:15:23 INFO  linkdevice.encodedecode - DECODE_START responseClass=LineupResDto payloadSize=45 bytes
2026-03-06 10:15:23 INFO  linkdevice.encodedecode - DECODE_END responseClass=LineupResDto duration=3ms
```

**api-calls.log.txt**:
```
2026-03-06 10:15:25 INFO  linkdevice.apicalls - API_CALL_START method=getLineupEntries
2026-03-06 10:15:25 INFO  linkdevice.apicalls - API_CALL_END method=getLineupEntries duration=210ms
2026-03-06 10:15:28 INFO  linkdevice.apicalls - API_CALL_START method=updateJobProgress
2026-03-06 10:15:28 INFO  linkdevice.apicalls - API_CALL_END method=updateJobProgress duration=185ms
```

**connection.log.txt**:
```
2026-03-06 10:10:00 INFO  linkdevice.connection - TCP_CONNECT_START host=192.168.1.10 port=4001 responseTimeout=30s connectTimeout=5s
2026-03-06 10:10:00 INFO  linkdevice.connection - TCP_CONNECT_SUCCESS duration=320ms
2026-03-06 10:15:23 INFO  linkdevice.connection - TCP_SEND_START payloadSize=1 bytes
2026-03-06 10:15:23 INFO  linkdevice.connection - TCP_SEND_END responseSize=1 bytes duration=30ms
```

### DEBUG (Dev/QA additions)
```
2026-03-06 10:15:23 DEBUG linkdevice.encodedecode - ENCODE_SHAPE messageType=LineupItemAddReqDto shape={"jobId":"String[6]","width":"Integer","length":"Integer"}
2026-03-06 10:15:25 DEBUG linkdevice.apicalls - API_CALL_SHAPE method=getLineupEntries response_shape={"converterJobs":"Collection[5]"}
```

### TRACE + hex enabled (logging.hex.enabled=true in dev/QA)
```
2026-03-06 10:15:23 INFO  linkdevice.encodedecode - ENCODE_START messageType=LineupReqDto
2026-03-06 10:15:23 INFO  linkdevice.encodedecode - ENCODE_END messageType=LineupReqDto duration=2ms payloadSize=12 bytes
2026-03-06 10:15:23 INFO  linkdevice.encodedecode - HEX_DUMP direction=TX protocol=Gopfert size=12 bytes
                       1   41 30 31 00 04 0D 0A 20 20 20 20 41   12
2026-03-06 10:15:23 INFO  linkdevice.encodedecode - DECODE_START responseClass=LineupResDto payloadSize=45 bytes
2026-03-06 10:15:23 INFO  linkdevice.encodedecode - HEX_DUMP direction=RX protocol=Gopfert size=45 bytes
41 30 31 00 04 0D 0A .      1   41 30 31 00 04 0D 0A 20 20 20 20  7
...
```

---

## 9. What We Are NOT Doing

- **No performance log file** — removed per review feedback
- **No MDC / request ID propagation** — single-threaded scheduler, sequential log ordering is sufficient
- **No raw payload logging at INFO** — TRACE only
- **No changes to other controller types** (BHS, ACS, File, Conveyor) in this phase — the `encodeWithLogging()` / `decodeWithLogging()` helpers in `GeneralControllerService` are available for them to adopt as follow-up work
- **No AOP on controller/TCP layers** — not Spring beans; direct structured logging is used instead

---

*Plan updated — hexdump added, ready for implementation.*
