# Implementation Plan: ADO-973277 – Order API (NLA Enhancement)

**ADO Work Item:** [#973277](https://dev.azure.com/advantive-devops/0e254f90-a87c-479e-abde-680deb67b476/_workitems/edit/973277)
**Date:** 2026-05-26
**Assigned To:** Laks Yalamati
**Sprint:** 26.2 Sprint 3
**Research Doc:** [ADO973277-research-20260526-071156.md](../research/ADO973277-research-20260526-071156.md)

---

## Overview

The three existing v1 Order API endpoints need to be enhanced to add three new optional fields (`startTime`, `runSpeed`, `targetRunSpeed`) required by NLA consumers (Convertor, Strapper, Conveyor). These fields are already computed in the `LineupEntry` model and are already exposed by the v3 lineup-entries API — the pattern is established and well-understood.

**Endpoints:**

| Endpoint | Method |
|---|---|
| `/kp-pcs-service/v1/orders/{orderNumber}/summary` | GET |
| `/kp-pcs-service/v1/orders/{orderNumber}/jobs/{jobNumber}/steps` | GET |
| `/kp-pcs-service/v1/orders/{orderNumber}/jobs/{jobNumber}/steps/{stepNumber}` | GET |

---

## Data Flow (current → new)

```
PcsServiceImpl.getOrderJobStep()          ← already fetches LineupEntry
  → OrderJobStepMapper.toDTO()            ← JINI mapper (kp-pcs-impl)
    [OrderJobStepDTO]                     ← JINI DTO (kp-pcs-api) — NEW fields here
  → OrderJobStepMapper.map()              ← REST mapper (kp-pcs-service-api)
    [OrderJobStepJsonDTO]                 ← REST DTO — NEW fields here
  → HTTP JSON response
```

---

## Files Changed Summary

| File | Change |
|---|---|
| `pcs/kp-pcs/kp-pcs-api/src/kiwiplan/pcs/model/lineups/OrderJobStepDTO.java` | Add `startTime`, `runSpeed`, `targetRunSpeed` |
| `pcs/kp-pcs/kp-pcs-impl/src/kiwiplan/pcs/mappers/OrderJobStepMapper.java` | Populate new fields from `LineupEntry` |
| `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/OrderJobStepJsonDTO.java` | Add `startTime`, `runSpeed`, `targetRunSpeed` |
| `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/mapper/OrderJobStepMapper.java` | Map new fields through |
| `pcs/kp-pcs-service/doc/step_api.yaml` | Document new fields in Step schema |
| `pcs/kp-pcs-service/src/test/java/com/kiwiplan/pcs/rest/model/mapper/TestOrderJobStepMapper.java` | Assert new fields are mapped |
| `pcs/kp-pcs-service/src/test/java/com/kiwiplan/pcs/rest/controller/TestOrderController.java` | Assert new fields appear in API response |

---

## Task 1 — Extend `OrderJobStepDTO` (JINI DTO)

**File:** `pcs/kp-pcs/kp-pcs-api/src/kiwiplan/pcs/model/lineups/OrderJobStepDTO.java`

Add `import java.util.Date;` and 3 new fields with getters/setters:

```java
private Date startTime;       // nullable — planned start time of the lineup entry
private long runSpeed;        // 0 when unknown — planned run speed (sheets/hour)
private long targetRunSpeed;  // 0 when unknown — target run speed (sheets/hour)
```

---

## Task 2 — Populate new fields in the JINI mapper

**File:** `pcs/kp-pcs/kp-pcs-impl/src/kiwiplan/pcs/mappers/OrderJobStepMapper.java`

In `toDTO(Step step, LineupEntry lineupEntry)`, add after the existing `materialsForStep` block:

```java
if (lineupEntry != null && lineupEntry.getPlannedStartTime() != null) {
    orderJobStepDTO.setStartTime(new Date(lineupEntry.getPlannedStartTime().getTimeInMillis()));
}

if (lineupEntry != null && lineupEntry.getPlannedMachineRunSpeed() != null) {
    orderJobStepDTO.setRunSpeed(lineupEntry.getPlannedMachineRunSpeed().getSpeedPerHour().getGrainAmount());
}

if (lineupEntry != null && lineupEntry.getTargetRunSpeed() != null) {
    orderJobStepDTO.setTargetRunSpeed(lineupEntry.getTargetRunSpeed().getSpeedPerHour().getGrainAmount());
}
```

Add `import java.util.Date;` if not already present.

> **Note:** When `lineupEntry` is null (step not yet on a machine lineup), all three fields default to `null`/`0` — backward-compatible.

---

## Task 3 — Extend `OrderJobStepJsonDTO` (REST DTO)

**File:** `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/OrderJobStepJsonDTO.java`

Add imports and 3 new fields:

```java
import com.fasterxml.jackson.annotation.JsonFormat;
import java.util.Date;

@JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ssXXX")
private Date startTime;      // nullable

private long runSpeed;       // defaults to 0

private long targetRunSpeed; // defaults to 0
```

Standard getters/setters for each. The `@JsonFormat` annotation matches the pattern already used in `StepDTOV3` and `PlannedPerformanceDTOV2`.

---

## Task 4 — Update the REST mapper

**File:** `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/mapper/OrderJobStepMapper.java`

In `map(OrderJobStepDTO pcsDto)`, add after the existing field mappings (before the `return dto;`):

```java
dto.setStartTime(pcsDto.getStartTime());
dto.setRunSpeed(pcsDto.getRunSpeed());
dto.setTargetRunSpeed(pcsDto.getTargetRunSpeed());
```

---

## Task 5 — Update the OpenAPI spec

**File:** `pcs/kp-pcs-service/doc/step_api.yaml`

Add the three new fields to the `Step` schema under `components/schemas/Step`:

```yaml
startTime:
  type: string
  format: date-time
  nullable: true
  description: Planned start time of the lineup entry (ISO 8601). Null if not yet scheduled.
runSpeed:
  type: integer
  format: int64
  description: Planned run speed in sheets per hour. 0 if not yet on a machine lineup.
targetRunSpeed:
  type: integer
  format: int64
  description: Target run speed in sheets per hour. 0 if not yet on a machine lineup.
```

---

## Task 6 — Update tests

### 6a. `TestOrderJobStepMapper.java`

**File:** `pcs/kp-pcs-service/src/test/java/com/kiwiplan/pcs/rest/model/mapper/TestOrderJobStepMapper.java`

In `testConvertStepToOrderJobStepDTO`, add to the JINI DTO setup:

```java
Date expectedStartTime = new Date();
pcsDto.setStartTime(expectedStartTime);
pcsDto.setRunSpeed(12000L);
pcsDto.setTargetRunSpeed(15000L);
```

Add assertions:

```java
assertEquals(expectedStartTime, dto.getStartTime());
assertEquals(12000L, dto.getRunSpeed());
assertEquals(15000L, dto.getTargetRunSpeed());
```

Add a new test `testConvertStepToOrderJobStepDTO_withNullStartTimeAndZeroSpeeds` verifying defaults (`null` startTime, `0` for speeds) when the JINI DTO has no lineup data set.

### 6b. `TestOrderController.java`

**File:** `pcs/kp-pcs-service/src/test/java/com/kiwiplan/pcs/rest/controller/TestOrderController.java`

In `getOrderJobStep()`, add to the stub DTO setup:

```java
Date expectedStartTime = new Date();
orderJobStepDTO.setStartTime(expectedStartTime);
orderJobStepDTO.setRunSpeed(12000L);
orderJobStepDTO.setTargetRunSpeed(15000L);
```

Add JSON path assertions:

```java
assertEquals(12000L, path.getLong("runSpeed"));
assertEquals(15000L, path.getLong("targetRunSpeed"));
assertNotNull(path.getString("startTime"));
```

---

## Key Reference: Conversion Patterns

These patterns are already established in `MachineManager.java` (v3 lineup-entries API):

| Value | Source | Conversion |
|---|---|---|
| `startTime` | `LineupEntry.getPlannedStartTime()` | `new Date(time.getTimeInMillis())` |
| `runSpeed` | `LineupEntry.getPlannedMachineRunSpeed()` | `.getSpeedPerHour().getGrainAmount()` |
| `targetRunSpeed` | `LineupEntry.getTargetRunSpeed()` | `.getSpeedPerHour().getGrainAmount()` |

---

## Backward Compatibility

- All three new fields are **additive** — no existing field is changed, removed, or renamed.
- `runSpeed` and `targetRunSpeed` default to `0` when no lineup entry exists, matching the v3 lineup API pattern.
- `startTime` is nullable — existing consumers that don't read it are unaffected.
- No version bump required per Kiwiplan API versioning policy.

---

## Out of Scope

- `OrderSummaryJsonDTO` (`/v1/orders/{orderNumber}/summary`) — no new fields identified for the summary endpoint from the feature design doc. No changes unless a consumer gap is found during NLA integration testing.
- Lineup v4 API, Feedback APIs, and Unit APIs — separate work items under parent [#970048](https://dev.azure.com/advantive-devops/0e254f90-a87c-479e-abde-680deb67b476/_workitems/edit/970048).
