## 🚀 Implementation Summary

**Date:** 2026-05-26 | **Author:** Laks Yalamati | **PR:** [PR #42600 — Implement NLA v2 Order/Job/Step API with mapping and controller](https://dev.azure.com/advantive-devops/Advantive/_git/KP-MapJava/pullrequest/42600)

### 📋 What Was Implemented

1. New `OrderControllerV2` REST controller exposing v2 Order/Job/Step endpoints at `/api/v2/orders/{orderNumber}/jobs/{jobNumber}/steps` (list) and `steps/{stepNumber}` (single), wrapping the existing `LineupService` with a v2-specific response shape.
2. New `OrderJobStepJsonDTOV2` response DTO extending the v1 shape with three NLA-required scheduling fields: `startTime` (ISO-8601 formatted planned start), `runSpeed` (planned sheets/hour), and `targetRunSpeed` (target sheets/hour).
3. New `OrderJobStepMapperV2` utility class that converts from the JINI-layer `OrderJobStepDTO` to the new `OrderJobStepJsonDTOV2`, including null-safe `ProgressStatus` enum bridging and material mapping delegation to the existing `MaterialForStepMapper`.
4. Extended the JINI API `OrderJobStepDTO` with the three new scheduling fields (`startTime`, `runSpeed`, `targetRunSpeed`) and a `serialVersionUID`, maintaining backward compatibility with existing v1 consumers.
5. Extended `OrderJobStepMapper` (JINI impl) to populate the three new fields from the `lineupEntry` when available (`plannedStartTime`, `plannedMachineRunSpeed`, `targetRunSpeed`), guarded by null checks.
6. Updated `WebSecurityConfig` and `PcsAuthenticationPatternConfigurator` to bypass authentication for the new `/api/v2/orders/{orderNumber}/jobs/{jobNumber}/steps/**` paths, matching the open-access pattern already used by other NLA endpoints.

### 🔨 Changes Made

**File:** `pcs/kp-pcs/kp-pcs-api/src/kiwiplan/pcs/model/lineups/OrderJobStepDTO.java`  
**Change:** Added `startTime` (Date), `runSpeed` (long), `targetRunSpeed` (long) fields with getters/setters. Added `serialVersionUID = 1L` to satisfy Serializable contract.

**File:** `pcs/kp-pcs/kp-pcs-impl/src/kiwiplan/pcs/mappers/OrderJobStepMapper.java`  
**Method:** `map(Step, LineupEntry)` (existing)  
**Change:** After the existing materials mapping block, three null-guarded blocks populate `startTime` from `lineupEntry.getPlannedStartTime()` (converted from Calendar to Date), `runSpeed` from `lineupEntry.getPlannedMachineRunSpeed().getSpeedPerHour().getGrainAmount()`, and `targetRunSpeed` from `lineupEntry.getTargetRunSpeed().getSpeedPerHour().getGrainAmount()`.

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

**File:** `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/v2/OrderJobStepJsonDTOV2.java`  
**Change:** New DTO class. Mirrors all v1 fields plus `startTime` (serialized as `yyyy-MM-dd'T'HH:mm:ssXXX` via `@JsonFormat`), `runSpeed` (long), and `targetRunSpeed` (long). Both speed fields default to 0 (step not yet scheduled onto a machine).

**File:** `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/mapper/v2/OrderJobStepMapperV2.java`  
**Change:** New static utility mapper. Converts single or list of `OrderJobStepDTO` to `OrderJobStepJsonDTOV2`. Guards against null input. Bridges `ProgressStatus` enums by name and delegates material mapping to `MaterialForStepMapper.mapToRest()`.

**File:** `pcs/kp-pcs-service/src/main/java/com/kiwiplan/pcs/rest/controller/OrderControllerV2.java`  
**Change:** New `@RestController` at `/api/v2/orders`. Exposes `GET .../jobs/{jobNumber}/steps` and `GET .../jobs/{jobNumber}/steps/{stepNumber}`. Catches `PcsServiceException` and rethrows as `OrderJobStepNotFoundException` (404) or `PcsServiceDelegateException`. Annotated with Spring Validation constraints on path variables (`@Positive`, `@NotBlank`).

**File:** `pcs/kp-pcs-service/src/main/java/com/kiwiplan/pcs/rest/config/WebSecurityConfig.java`  
**Change:** Added `NegatedRequestMatcher` for `/api/v2/orders/{orderNumber}/jobs/{jobNumber}/steps/**` to the non-secured matcher chain.

**File:** `pcs/kp-pcs-service/src/main/java/com/kiwiplan/pcs/rest/config/auth/PcsAuthenticationPatternConfigurator.java`  
**Change:** Added `.mvcMatchers("/api/v2/orders/{orderNumber}/jobs/{jobNumber}/steps/**")` to the permitted (unauthenticated) matchers.

### 💡 How It Works

- The v2 endpoints re-use the existing `LineupService.getOrderJobStep()` and `getOrderJobSteps()` JINI calls, which now return the three new scheduling fields alongside the existing step data. No new JINI service calls were introduced.
- `OrderJobStepMapperV2` is a thin, stateless converter that sits between the enriched JINI DTO and the NLA REST contract, keeping the v1 mapper and controller completely untouched and preserving backward compatibility.
- Scheduling fields are null-/zero-safe by design: `startTime` is null when the step has not been placed on a lineup; `runSpeed` and `targetRunSpeed` default to `0` when no machine assignment exists. NLA consumers can test for null/zero to detect the unscheduled case.
- Security bypass follows the same pattern already established for other NLA-facing endpoints (`/api/v1/plants/**`, `/api/v1/health/**`), ensuring the new routes are accessible without authentication.

### 📁 Key Files

| File | Change |
|---|---|
| `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/v2/OrderJobStepJsonDTOV2.java` | New NLA v2 response DTO with `startTime`, `runSpeed`, `targetRunSpeed` |
| `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/mapper/v2/OrderJobStepMapperV2.java` | New static mapper from JINI `OrderJobStepDTO` to v2 REST DTO |
| `pcs/kp-pcs-service/src/main/java/com/kiwiplan/pcs/rest/controller/OrderControllerV2.java` | New v2 REST controller at `/api/v2/orders` |
| `pcs/kp-pcs/kp-pcs-api/src/kiwiplan/pcs/model/lineups/OrderJobStepDTO.java` | Extended with `startTime`, `runSpeed`, `targetRunSpeed` fields and `serialVersionUID` |
| `pcs/kp-pcs/kp-pcs-impl/src/kiwiplan/pcs/mappers/OrderJobStepMapper.java` | Populates new scheduling fields from `lineupEntry` |
| `pcs/kp-pcs-service/src/main/java/com/kiwiplan/pcs/rest/config/WebSecurityConfig.java` | Added v2 order/steps path to non-secured matcher |
| `pcs/kp-pcs-service/src/main/java/com/kiwiplan/pcs/rest/config/auth/PcsAuthenticationPatternConfigurator.java` | Added v2 order/steps path to auth bypass |
| `pcs/kp-pcs-service/src/test/java/com/kiwiplan/pcs/rest/controller/TestOrderControllerV2.java` | New controller tests (happy path, error cases, path validation) |
| `pcs/kp-pcs-service/src/test/java/com/kiwiplan/pcs/rest/model/mapper/v2/TestOrderJobStepMapperV2.java` | New unit tests for `OrderJobStepMapperV2` (null safety, enum round-trip, list mapping) |
