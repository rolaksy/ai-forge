# PR: Added detailed observability logging to Link Device

## Summary

Three new dedicated log files have been added. All channels are independently controlled via log level configuration in `linkdevice.yml`.

---

## New log files

| File | Logger | Purpose |
|------|--------|---------|
| `encode-decode.log.txt` | `com.kiwiplan.linkdevice.encodedecode` | Protocol encode/decode steps, timing, payload shape, and optional hex dump |
| `api-calls.log.txt` | `com.kiwiplan.linkdevice.apicalls` | LinkCentral API call lifecycle — start, end, and errors |
| `connection.log.txt` | `com.kiwiplan.linkdevice.connection` | TCP connect/disconnect events |

---

## Logging configuration (`linkdevice.yml`)

```yaml
logging:
  level:
    # Protocol encode/decode operations
    com.kiwiplan.linkdevice.encodedecode: INFO

    # LinkCentral API call lifecycle (set DEBUG for response shape summaries)
    com.kiwiplan.linkdevice.apicalls: INFO

    # TCP connection events
    com.kiwiplan.linkdevice.connection: INFO

  # Hex dump logging (off by default; enable for byte-level troubleshooting)
  hex:
    enabled: false   # Set to true to emit xmgen-style hex dumps in encode-decode.log.txt
```

---

## New classes

### `PayloadShapeExtractor`

Utility class that extracts a field-name/type summary from protocol DTOs using the Java Beans API (`Introspector`). No raw field values are included — safe for production logging.

### `LinkDeviceLoggingConfig`

Spring `@Component` that reads the `logging.hex.enabled` flag at startup and exposes it to the logging infrastructure via a static accessor.

### `ProtocolSerializationService`

Spring-managed service dedicated to protocol message serialization. All `encode`/`decode` calls from controller services are routed through this service.

Provides structured log entries at appropriate levels:

| Event | Level | Content |
|-------|-------|---------|
| `ENCODE_START` | INFO | Message type |
| `ENCODE_END` | INFO | Message type, duration (ms), payload size (bytes) |
| `ENCODE_SHAPE` | DEBUG | Field-name/type summary — no raw values |
| `ENCODE_PAYLOAD` | TRACE | Full encoded payload |
| `DECODE_START` | INFO | Response class, payload size (bytes) |
| `DECODE_END` | INFO | Response class, duration (ms) |
| `DECODE_SHAPE` | DEBUG | Field-name/type summary — no raw values |
| `DECODE_PAYLOAD` | TRACE | Full raw payload |
| `HEX_DUMP TX/RX` | INFO | Raw bytes in xmgen-style hex format (requires `logging.hex.enabled=true`) |

### `LinkCentralApiLoggingAspect`

Spring AOP aspect that intercepts all `LinkCentralClient` method calls and emits structured log entries to `api-calls.log.txt`:

| Event | Level | Content |
|-------|-------|---------|
| `API_CALL_START` | INFO | Method name |
| `API_CALL_END` | INFO | Method name, duration (ms) |
| `API_CALL_ERROR` | ERROR | Method name, duration (ms), error message |
| `API_CALL_SHAPE` | DEBUG | Response field-name/type summary |

---

## Refactoring

Encode/decode logic and hex-dump construction extracted from `GeneralControllerService` into the new injectable `ProtocolSerializationService`. This keeps controller services focused on their protocol-specific workflows and makes the serialization behaviour independently testable.

---

## Testing

To enable all logging channels with hex dump, set the following in `linkdevice.yml`:

```yaml
logging:
  level:
    com.kiwiplan.linkdevice.encodedecode: INFO
    com.kiwiplan.linkdevice.apicalls: DEBUG
    com.kiwiplan.linkdevice.connection: INFO
  hex:
    enabled: true
```
