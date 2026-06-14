# ADO 923969 — Spike: Determine WIP vs FGS in LinkDevice (Java)

**Work Item:** [ADO 923969](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/923969)  
**Prior Spike Reference:** [ADO 907453 – Comment #26575176](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/907453#26575176)  
**TL Recommendation:** [Peter Wang – Comment #26588167](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/907453#26588167)

---

## 1. Background

The prior spike (ADO 907453) investigated whether the Fortran subroutine `wip_into_fgs` could be reimplemented in the Java-based system. That spike analysed the function in full and concluded **"Go with Changes in NLA"** — i.e., feasible with modifications.

The original proposal placed the business logic inside **LinkCentral**. The TL (**Peter Wang**) reviewed and recommended a revised approach:

> "Please keep Link Central only having one responsibility: fetching data from the database. Let Link Device handle all the business logic check."

This spike investigates what changes are needed in **LinkCentral** (data layer) and **LinkDevice** (logic layer) to implement this cleanly, following Peter Wang's suggested workflow.

---

## 2. Acceptance Criteria (ADO 923969)

- **Given** job routing and machine data is available  
- **When** LinkDevice evaluates finishing operations  
- **Then** stacks with finishing operations are classified as **FGS**  
- **And** others are classified as **WIP**  
- **And** logic matches VUE decision flow

---

## 3. Approved Workflow (TL's Recommendation)

```
LinkDevice  →  [New API Call]  →  LinkCentral (data fetch only)
                                        ↓
                              Query WORKIP / FACTRY / CSCNTR / XLATEP
                                        ↓
                              Return raw DTO (WipFgsDataDto)
                                        ↓
LinkDevice  →  [Business Logic]  →  Determine WIP or FGS
                                        ↓
                              Perform action (dispatch/WIP routing)
```

---

## 4. `wip_into_fgs` Logic Summary (from ADO 907453)

### Inputs
| Parameter | Type | Description |
|---|---|---|
| `job_key` | String (10) | PCS job key identifier |
| `job_series` | String (1) | Job series number |
| `step_in` | Integer | Manufacturing step to start evaluation from |

### Output
- `0` = **WIP** (still being processed)
- `1` = **FGS** (ready for dispatch/shipping)

### Decision Flow
1. **No PCS database** → default `FGS = 1`
2. **Look up machine** from WORKIP (by job/series/step); fall back to FACTRY
3. **Dispatch check**: if machine has bit 20 set (`possible_operation`) → FGS immediately
4. **Load CSCNTR** for machine (`no_work_stations`, `possible_operation`, `extra_operations`)
5. **Auto-feedback detection**: `no_work_stations == -1 or -2`, unless bit 39 or bit 14 is set
6. **Receive check**: bit 29 of `possible_operation` = "From Supplier"
7. **Strapper check**: after clearing bits 28,29 (supplier) and 10,11 (strap/shrinkwrap), if ops are empty → `have_strap = true`
8. **Outside Collation**: bits 37 + 14 both set → FGS
9. **WIP Tracking + Receive** → WIP immediately
10. **Step loop**: if conditions unresolved (`auto_feedback || have_strap || wip_with_receive || step==1`) — increment step and repeat
11. **Final**: if `have_strap` → FGS; else WIP

### WIP Tracking Flag Source
- From XLATEP table: `SYS/MO` record, `xl_body` position 66 (1 char)
- Already supported via `XlatepDAO.getSubstringFromXlBody("SYS", "MO", 66, 1)`

---

## 5. Repositories Investigated

| Repo | Path | Purpose |
|---|---|---|
| KP-Xmit-LinkCentral | `/home/laksyalamati/projects/KP-Xmit-LinkCentral` | Spring Boot data service (REST API + DB access) |
| KP-Xmit-LinkDevice | `/home/laksyalamati/projects/KP-Xmit-LinkDevice` | Spring Boot device bridge (controller calls + LinkCentral API calls) |

---

## 6. LinkCentral — Current State & Required Changes

### 6.1. Existing DAOs Available

| DAO | Table | Current Capabilities | Gap for WIP/FGS |
|---|---|---|---|
| `WorkipDAO` | WORKIP | Query by `job_number + machine_number + series_number + step_number` | **Missing**: query WITHOUT machine_number |
| `FactryDAO` | FACTRY | Query by `job_number + machine_number + step_number + series_number` | **Missing**: query WITHOUT machine_number |
| `CscntrDAO` | CSCNTR | Query `machine_number, possible_operation` | **Missing**: `no_work_stations`, `extra_operations`, `schedule_y_n_low` filter |
| `XlatepDAO` | XLATEP | `getSubstringFromXlBody(system, prefix, pos, len)` | **No gap** — `getSubstringFromXlBody("SYS", "MO", 66, 1)` works for WIP tracking flag |

### 6.2. Required Changes in LinkCentral

#### A. `WorkipDAO` — Add method without machine number
```java
// New method: get machine number from WORKIP by job/series/step (no machine_number needed)
public Optional<Integer> getMachineNumberByJobStep(String jobNumber, int seriesNumber, int stepNumber) {
    Map<String, Object> params = new HashMap<>();
    params.put("jobNumber", jobNumber);
    params.put("seriesNumber", seriesNumber);
    params.put("stepNumber", stepNumber);
    String queryStr = "SELECT machine_number FROM WORKIP "
        + "WHERE job_number = :jobNumber "
        + "AND series_number = :seriesNumber "
        + "AND step_number = :stepNumber";
    return fetchSingleValueByParams(queryStr, params, Integer.class);
}
```

#### B. `FactryDAO` — Add method without machine number
```java
// New method: get machine number from FACTRY by job/series/step (fallback when WORKIP miss)
public Optional<Integer> getMachineNumberByJobStep(String jobNumber, int seriesNumber, int stepNumber) {
    Map<String, Object> params = new HashMap<>();
    params.put("jobNumber", jobNumber);
    params.put("seriesNumber", seriesNumber);
    params.put("stepNumber", stepNumber);
    String queryStr = "SELECT machine_number FROM FACTRY "
        + "WHERE job_number = :jobNumber "
        + "AND series_number = :seriesNumber "
        + "AND step_number = :stepNumber";
    return fetchSingleValueByParams(queryStr, params, Integer.class);
}
```

#### C. `CSCNTR` DTO — Add missing fields
The current `CSCNTR.java` only has `machineNumber` and `possibleOperation`. The WIP/FGS logic also needs:

```java
// Add to CSCNTR.java (or create a new WipFgsMachineInfo DTO)
private Integer noWorkStations;     // ctr_num_stations: -1 or -2 = auto-feedback
private Integer extraOperations;    // ctr_extra_ops: bits 39, 14 for outsourcing check
```

#### D. `CscntrDAO` — Add new query method
The existing `getMachineType()` only queries `machine_number, possible_operation`. A new method is needed:

```java
public Optional<WipFgsMachineCapabilities> getMachineCapabilities(Integer machineNumber) {
    Map<String, Object> params = new HashMap<>();
    params.put("machineNumber", machineNumber);
    String query = "SELECT machine_number, no_work_stations, possible_operation, extra_operations "
        + "FROM CSCNTR "
        + "WHERE schedule_y_n_low != 'N' "
        + "AND machine_number = :machineNumber";
    // Returns a new DTO: WipFgsMachineCapabilities
}
```

> **Note**: A separate DTO `WipFgsMachineCapabilities` is recommended to avoid polluting `MachineInfo`.

#### E. New DTO: `WipFgsMachineCapabilities` (LinkCentral internal)
```java
public class WipFgsMachineCapabilities {
    private Integer machineNumber;
    private Integer noWorkStations;    // ctr_num_stations
    private Integer possibleOperation; // ctr_poss_ops (parsed as int)
    private Integer extraOperations;   // ctr_extra_ops
}
```

#### F. New Response DTO: `WipFgsDataDto` (returned to LinkDevice)
```java
// Package: com.kiwiplan.link.linkcentral.dto
public class WipFgsDataDto {
    private Integer machineNumber;        // from WORKIP or FACTRY (null = no record found)
    private Integer possibleOperations;   // from CSCNTR (null = machine not found in CSCNTR)
    private Integer extraOperations;      // from CSCNTR
    private Integer numberOfWorkStations; // from CSCNTR (no_work_stations / ctr_num_stations)
    private boolean wipTrackingEnabled;   // from XLATEP SYS/MO position 66 == "1"
    private boolean noPcsDatabase;        // true if WORKIP/FACTRY/CSCNTR unavailable
}
```

#### G. New Service: `WipFgsService` (LinkCentral)
Pure data-fetching service — no business logic:

```java
@Service
public class WipFgsService {

    private final WorkipDAO workipDAO;
    private final FactryDAO factryDAO;
    private final CscntrDAO cscntrDAO;
    private final XlatepDAO xlatepDAO;

    public WipFgsDataDto getWipFgsData(String jobNumber, int seriesNumber, int stepNumber) {
        WipFgsDataDto dto = new WipFgsDataDto();

        // 1. Get WIP tracking flag from XLATEP SYS/MO pos 66
        String wipFlag = xlatepDAO.getSubstringFromXlBody("SYS", "MO", 66, 1);
        dto.setWipTrackingEnabled("1".equals(wipFlag));

        // 2. Look up machine number: WORKIP first, then FACTRY
        Optional<Integer> machineNumber = workipDAO.getMachineNumberByJobStep(jobNumber, seriesNumber, stepNumber);
        if (machineNumber.isEmpty()) {
            machineNumber = factryDAO.getMachineNumberByJobStep(jobNumber, seriesNumber, stepNumber);
        }

        if (machineNumber.isEmpty()) {
            // No record found for this step
            return dto; // machineNumber null, noPcsDatabase false
        }

        dto.setMachineNumber(machineNumber.get());

        // 3. Get machine capabilities from CSCNTR
        Optional<WipFgsMachineCapabilities> capabilities = cscntrDAO.getMachineCapabilities(machineNumber.get());
        capabilities.ifPresent(caps -> {
            dto.setPossibleOperations(parseIntSafe(caps.getPossibleOperation()));
            dto.setExtraOperations(caps.getExtraOperations());
            dto.setNumberOfWorkStations(caps.getNoWorkStations());
        });

        return dto;
    }
}
```

#### H. New Controller Endpoint: `WipFgsController` (LinkCentral)
```java
@RestController
@RequestMapping("/api/v1")
public class WipFgsController {

    private final WipFgsService wipFgsService;

    @GetMapping("/jobs/{jobNumber}/series/{seriesNumber}/step/{stepNumber}/wip-fgs-data")
    public ResponseEntity<WipFgsDataDto> getWipFgsData(
            @PathVariable String jobNumber,
            @PathVariable int seriesNumber,
            @PathVariable int stepNumber) {
        return ResponseEntity.ok(wipFgsService.getWipFgsData(jobNumber, seriesNumber, stepNumber));
    }
}
```

**Alternative URL** (query params style used in some endpoints):
```
GET /api/v1/jobs/wip-fgs-data?jobNumber={}&seriesNumber={}&stepNumber={}
```

---

## 7. LinkDevice — Required Changes

### 7.1. New DTO: `WipFgsDataDto`
Minor: Create in `dto/linkcentral/` to match LinkCentral's response:

```java
// Package: com.kiwiplan.linkdevice.dto.linkcentral
public class WipFgsDataDto {
    private Integer machineNumber;
    private Integer possibleOperations;
    private Integer extraOperations;
    private Integer numberOfWorkStations;
    private boolean wipTrackingEnabled;
    private boolean noPcsDatabase;
    // getters/setters
}
```

### 7.2. Update `LinkCentralClient` Interface

```java
// Add to LinkCentralClient.java
WipFgsDataDto getWipFgsData(String jobNumber, int seriesNumber, int stepNumber);
```

### 7.3. Implement in `LinkCentralClientImpl`

```java
@Override
public WipFgsDataDto getWipFgsData(String jobNumber, int seriesNumber, int stepNumber) {
    HttpUrl url = getDefaultHttpUrlBuilder()
        .addPathSegment("v1")
        .addPathSegment("jobs")
        .addPathSegment(jobNumber)
        .addPathSegment("series")
        .addPathSegment(String.valueOf(seriesNumber))
        .addPathSegment("step")
        .addPathSegment(String.valueOf(stepNumber))
        .addPathSegment("wip-fgs-data")
        .build();
    return get(url, WipFgsDataDto.class);
}
```

### 7.4. New Service: `WipFgsService` (LinkDevice — Business Logic)

Java equivalent of the Fortran `wip_into_fgs`. All business logic lives here:

```java
@Service
public class WipFgsService {

    private final LinkCentralClient linkCentralClient;

    /**
     * Determines if a job step is WIP or FGS.
     * Java reimplementation of Fortran wip_into_fgs.
     *
     * @param jobNumber    PCS job number
     * @param seriesNumber job series number
     * @param startStep    manufacturing step to evaluate from
     * @return true = FGS (finished goods stock), false = WIP
     */
    public boolean isFgs(String jobNumber, int seriesNumber, int startStep) {
        boolean fgs = false;
        boolean haveStrap = false;
        int step = startStep;

        while (true) {
            WipFgsDataDto data = linkCentralClient.getWipFgsData(jobNumber, seriesNumber, step);

            // No PCS database → default FGS
            if (data.isNoPcsDatabase()) {
                return true;
            }

            // No machine found at this step → end of route
            if (data.getMachineNumber() == null) {
                break;
            }

            int possibleOps = data.getPossibleOperations() != null ? data.getPossibleOperations() : 0;
            int extraOps = data.getExtraOperations() != null ? data.getExtraOperations() : 0;
            int numStations = data.getNumberOfWorkStations() != null ? data.getNumberOfWorkStations() : 0;
            boolean wipTrackingEnabled = data.isWipTrackingEnabled();

            // Step 1: Dispatch check — bit 20 of possible_operation = dispatch machine
            if (isBitSet(possibleOps, 20)) {
                return true; // FGS — dispatch machine
            }

            // Auto-feedback: no_work_stations == -1 or -2
            boolean autoFeedback = (numStations == -1 || numStations == -2);
            // Exception: not auto-feedback if outsourcing ops present (bits 39 or 14)
            if (autoFeedback && (isBitSet(extraOps, 39) || isBitSet(possibleOps, 14))) {
                autoFeedback = false;
            }

            // Receive check: bit 29 = "From Supplier" operation
            boolean hasReceive = isBitSet(possibleOps, 29);

            // Clear supplier bits (28, 29)
            int filteredOps = clearBit(possibleOps, 28);
            filteredOps = clearBit(filteredOps, 29);

            // Strapper check: clear strap/shrinkwrap bits (10, 11)
            int strapCheckOps = clearBit(filteredOps, 10);
            strapCheckOps = clearBit(strapCheckOps, 11);
            // have_strap = only strap/shrinkwrap ops remain (after clearing supplier bits)
            if (strapCheckOps == 0 && filteredOps != 0) {
                haveStrap = true;
            }

            // Outside Collation: bits 37 (shuffle) + 14 (outside work)
            if (isBitSet(possibleOps, 37) && isBitSet(possibleOps, 14)) {
                return true; // FGS
            }

            // WIP tracking enabled + receive operation = WIP (exit early)
            if (wipTrackingEnabled && hasReceive) {
                return false; // WIP
            }

            // FGS decision: strapper only (no WIP tracking)
            if (!wipTrackingEnabled && haveStrap) {
                fgs = true;
            }

            // Continue loop: auto-feedback, strapper, or WIP-tracking-with-receive,
            // or step 1 forces next step check
            if (!fgs && (autoFeedback || haveStrap
                    || (wipTrackingEnabled && hasReceive)
                    || step == 1)) {
                step++;
                continue;
            }

            break;
        }

        // Final strapper determination
        if (haveStrap) {
            return true; // FGS
        }

        return fgs;
    }

    // --- Bitwise utility methods (Java equivalent of Fortran btest/ibclr) ---

    private boolean isBitSet(int value, int bitPosition) {
        return (value & (1 << bitPosition)) != 0;
    }

    private int clearBit(int value, int bitPosition) {
        return value & ~(1 << bitPosition);
    }
}
```

### 7.5. Integration Point in LinkDevice

The WIP/FGS determination is triggered when a **job completion event** arrives (history processing). The result determines what action to take:

- **FGS** → Mark as finished goods / dispatch routing
- **WIP** → Materials proceed to next production step (no special action)

**Integration in `CorrugatorLinkService` or `GeneralLinkService`**:

```java
// Inside processHistoryData(), after mapping history data:
boolean isFgs = wipFgsService.isFgs(
    lineupItemInfo.getOrderNumber(),   // jobNumber
    lineupItemInfo.getJobNumber(),     // seriesNumber (note: naming convention in LineupItemInfo)
    lineupItemInfo.getStepNumber()     // step
);

if (isFgs) {
    log.info("Job {} step {} classified as FGS", lineupItemInfo.getOrderNumber(), lineupItemInfo.getStepNumber());
    // Perform FGS-specific action
} else {
    log.info("Job {} step {} classified as WIP", lineupItemInfo.getOrderNumber(), lineupItemInfo.getStepNumber());
    // Perform WIP routing action
}
```

---

## 8. Gaps & Issues Found

| # | Gap | Severity | Resolution |
|---|---|---|---|
| 1 | `CSCNTR` DTO missing `no_work_stations` and `extra_operations` fields | High | Extend existing or create `WipFgsMachineCapabilities` DTO |
| 2 | `CscntrDAO` only queries 2 fields; needs `no_work_stations`, `extra_operations`, `schedule_y_n_low` filter | High | Add new `getMachineCapabilities()` method |
| 3 | `WorkipDAO` has no query without `machine_number` | High | Add `getMachineNumberByJobStep()` method |
| 4 | `FactryDAO` has no query without `machine_number` | High | Add `getMachineNumberByJobStep()` method |
| 5 | No `WipFgsService` or `WipFgsController` in LinkCentral | High | Create both (data-only) |
| 6 | No `WipFgsDataDto` in LinkDevice or LinkCentral | High | Create in both repos |
| 7 | `LinkCentralClient` interface doesn't include WIP/FGS call | High | Add method and implement |
| 8 | Step iteration across multiple steps = multiple API calls | Medium | Acceptable — steps are bounded (typically 1-5); each call is lightweight |
| 9 | `XLATEP SYS/MO` field for WIP tracking at position 66 — confirm position is 1-based | Low | Verify with `XlatepDAO.getSubstringFromXlBody("SYS", "MO", 66, 1)` test |
| 10 | `possible_operation` in CSCNTR is stored as String in current code | Low | Must parse to int before bitwise ops; use `Integer.parseInt()` with null check |

---

## 9. Files to Create/Modify

### LinkCentral (`KP-Xmit-LinkCentral`)

| Action | File Path |
|---|---|
| **Modify** | `dao/classic/WorkipDAO.java` — add `getMachineNumberByJobStep()` |
| **Modify** | `dao/classic/FactryDAO.java` — add `getMachineNumberByJobStep()` |
| **Modify** | `dao/classic/CscntrDAO.java` — add `getMachineCapabilities()` |
| **Create** | `dto/classic/WipFgsMachineCapabilities.java` — internal machine data DTO |
| **Create** | `dto/WipFgsDataDto.java` — response DTO returned to LinkDevice |
| **Create** | `service/WipFgsService.java` — data-fetch service (no business logic) |
| **Create** | `controller/WipFgsController.java` — REST endpoint |

### LinkDevice (`KP-Xmit-LinkDevice`)

| Action | File Path |
|---|---|
| **Create** | `dto/linkcentral/WipFgsDataDto.java` — mirrors LinkCentral response DTO |
| **Modify** | `config/client/LinkCentralClient.java` — add `getWipFgsData()` |
| **Modify** | `config/client/LinkCentralClientImpl.java` — implement `getWipFgsData()` |
| **Create** | `service/WipFgsService.java` — business logic (Java rewrite of `wip_into_fgs`) |
| **Modify** | `link/CorrugatorLinkService.java` (or equivalent) — call `WipFgsService` at job completion |

---

## 10. API Design

### New LinkCentral Endpoint

```
GET /api/v1/jobs/{jobNumber}/series/{seriesNumber}/step/{stepNumber}/wip-fgs-data
```

**Response (200 OK)**:
```json
{
  "machineNumber": 5,
  "possibleOperations": 4194304,
  "extraOperations": 0,
  "numberOfWorkStations": 1,
  "wipTrackingEnabled": false,
  "noPcsDatabase": false
}
```

**Response when no machine found for step (still 200 OK)**:
```json
{
  "machineNumber": null,
  "possibleOperations": null,
  "extraOperations": null,
  "numberOfWorkStations": null,
  "wipTrackingEnabled": false,
  "noPcsDatabase": false
}
```

---

## 11. Feasibility & Recommendation

### Verdict: **GO**

The implementation is straightforward based on the existing code patterns:
- LinkCentral already has the data access infrastructure (DAOs, JDBI, DB connections)
- LinkDevice already has the HTTP client pattern (`LinkCentralClientImpl` with OkHttp)
- Business logic is well-understood from the Fortran analysis in ADO 907453
- The Java bitwise operations are trivial (`isBitSet`, `clearBit`)

### Key Design Decisions

1. **Single step per API call**: LinkDevice calls LinkCentral once per step in the loop. Since steps are bounded (typically 1–5 in a job route), this is acceptable. Each call is extremely lightweight (machine number lookups in indexed tables).

2. **Separation of concerns** (TL-aligned): LinkCentral is purely a DB read. All conditional logic, bit operations, and step iteration stay in LinkDevice.

3. **XLATEP WIP tracking**: The `SYS/MO` record fetch can be cached per LinkDevice session startup (loaded once on init) since this is a system-wide setting that doesn't change per job. This reduces DB calls significantly.

4. **No machine found = no-op**: When `machineNumber` is null in the response, the step loop terminates and the result defaults to `fgs = false` (WIP), which matches the Fortran logic.

### Performance Considerations
- WORKIP and FACTRY queries: indexed tables, sub-millisecond
- CSCNTR query: small table (one row per machine), low DB load
- XLATEP (WIP tracking flag): load once at startup, cache in-memory
- Total overhead per job finish event: 2–5 API calls (one per step) at ~5ms each

---

## 12. Summary

| Component | Change Type | Complexity |
|---|---|---|
| LinkCentral – WorkipDAO | Extend (1 method) | Low |
| LinkCentral – FactryDAO | Extend (1 method) | Low |
| LinkCentral – CscntrDAO | Extend (1 method + new DTO) | Low |
| LinkCentral – WipFgsDataDto | New class | Low |
| LinkCentral – WipFgsService | New class (data-only) | Low |
| LinkCentral – WipFgsController | New controller | Low |
| LinkDevice – WipFgsDataDto | New class | Low |
| LinkDevice – LinkCentralClient | Extend interface + impl | Low |
| LinkDevice – WipFgsService | New class (business logic) | Medium |
| LinkDevice – Integration | Modify existing link service | Low |

**Total estimated effort**: 5 story points (matches existing estimate for ADO 923969)

---

*Spike completed: April 13, 2026*  
*Investigated by: Laks Yalamati*
