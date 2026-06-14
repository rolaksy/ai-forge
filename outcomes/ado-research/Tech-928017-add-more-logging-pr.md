# Tech-928017 — Add better logging to LinkCentral

## What's this about?

When something goes wrong in production (or even when things are working fine), the logs weren't telling us much. You'd see errors pop up but couldn't easily tell *which API call triggered it*, *how long it took*, or *which request thread was involved*. This PR fixes that.

---

## What changed and why

### 1. Every log line now shows thread and request ID

Before:
```
2026-03-10 14:23:01 INFO  LineupEntryClassicService - Accessing database for machine: 5
```

After:
```
2026-03-10 14:23:01 INFO  [http-nio-8080-exec-3] [rid=LC-1741603381234-0042] LineupEntryClassicService - Accessing database for machine: 5
```

The `rid` (request ID) ties every log line from the same HTTP request together — so if a request touches 5 services, you can grep for that one ID and see the whole story. Non-request logs (startup, polling) show `STARTUP` so they're easy to filter out too.

The thread name is useful when debugging concurrency issues or identifying which executor pool is doing what.

**Files changed:** `logback-spring.xml`

---

### 2. Request ID is now thread-safe

`RequestIdHolder` was previously storing the request ID in a plain `String` field on a singleton bean. Under concurrent load, requests would bleed into each other's log context. It now uses SLF4J's `MDC` (Mapped Diagnostic Context), which stores the value per-thread.

We also generate our own request ID (`LC-<timestamp>-<sequence>`) if the caller doesn't provide an `X-Request-ID` header. The format is short and readable — far less noise than a UUID.

**Files changed:** `RequestIdHolder.java`

---

### 3. Every API call is now logged automatically — no controller changes needed

Rather than adding logger calls to every controller (which would mean repeating the same pattern in 10+ places), we enhanced the existing `StandardHandlerInterceptor` which sits in front of all requests.

It now logs:
- **Incoming:** method, URI, client IP, path variables, and query params
- **Outgoing:** method, URI, HTTP status, and how long it took in ms

```
INFO >>> GET /api/v1/machines/5/lineup | client=10.0.0.1 | path={machineNumber=5} | query={limit=10}
INFO <<< GET /api/v1/machines/5/lineup | status=200 | elapsed=43ms
```

If the client doesn't send `X-Request-ID`, a new ID is auto-generated and attached to the MDC immediately — so even the "incoming" log line already carries the request ID.

**Files changed:** `StandardHandlerInterceptor.java`

---

### 4. Services now log what they're actually doing

A few key services had no logging at all, or had very vague logs like "Accessing database" with no context. Fixed in three services:

**`LineupEntryClassicService`**
- Logs entry into `updateJobProgress` and `finishJob` with machine and job number
- Logs success after each write operation completes
- Lineup fetch now logs how many entries were returned (converter vs corrugator split)

**`JobSpecificationClassicService`**
- Had no logger at all — added one
- Logs the order number being looked up and whether a spec was found or not
- Warns if the DAO returns null (previously this would silently NPE downstream)

**`InventoryUnitClassicService`**
- Replaced "Accessing database" / "Access completed" with the actual barcode being looked up
- Logs a `WARN` when a barcode isn't found, before throwing the 404 — so the warning and the error are now both visible in the log

---

## Files changed

| File | What |
|------|------|
| `src/main/resources/logback-spring.xml` | Added `[%thread]` and `[rid=%X{requestId:-STARTUP}]` to log pattern; log level set to `debug` |
| `config/RequestIdHolder.java` | Replaced plain `String` field with MDC; added `generateRequestId()` |
| `config/StandardHandlerInterceptor.java` | Logs all requests/responses with params and timing; auto-generates request ID |
| `service/impl/classic/LineupEntryClassicService.java` | Added entry/exit logs to write operations; improved lineup result log |
| `service/impl/classic/JobSpecificationClassicService.java` | New logger; logs order lookup and result |
| `service/impl/classic/InventoryUnitClassicService.java` | Replaced vague logs with barcode-specific info + warn on not found |

---

## How to test

Run the app and hit any endpoint. You should see paired `>>>` / `<<<` log lines with a consistent `rid` value. To trace a full request, grep for the request ID:

```bash
grep "LC-1741603381234-0042" linkcentral.log.txt
```

All lines for that request — across interceptor, service, DAO — will appear.
