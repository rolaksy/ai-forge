# ADO 923969 — Investigation: Existing WIP vs FGS Implementation in KP-MapJava

**Date:** April 21, 2026  
**Investigator:** Laks Yalamati  
**Related SCM:** 286184 — *Display the default label type based on the selected knife*  
**Related Spike:** [ADO923969-wip-fgs-linkdevice-spike.md](../ADO923969-wip-fgs-linkdevice-spike.md)

---

## 1. Purpose

Investigate whether the existing WIP vs FGS classification logic in KP-MapJava (`PrintLabelPanel.getDefaultLabelType`) is similar in intent to the Fortran `wip_into_fgs` subroutine, and assess whether it can serve as a reference or reuse point for the LinkDevice implementation.

---

## 2. SCM 286184 — Background Context (from PDF)

**Title:** Display the default label type based on the selected knife  
**Application:** CSC VUE (Corrugator Operator GUI)  
**Status:** Completed (MES 9.20.4 and 9.10.7)  
**Acceptance Criteria (from SCM):**

1. Change GUI: order selection comes first, then label type.
2. Upon opening the label printing panel, always default to the **first knife**, so default label type is always for the first knife.
3. When user picks a different order, the label type should update to reflect that order (one order defaults to WIP, another to FG).
4. If user changes label type manually for an order, switching back to that order resets to the route-based default (not the manually overridden value) — memory of selection only persists per session.

**Key test scenario described:** "Have one order defaulting to WIP and another defaulting to FG."

This tells us the system already has a working notion of per-order WIP/FG classification, driven by the job's remaining route.

---

## 3. File Location

```
/home/laksyalamati/projects/KP-MapJava/csc/kp-csc-gui/src/kiwiplan/csc/gui/panels/PrintLabelPanel.java
```

Package: `kiwiplan.csc.gui.panels`

> **Note:** There is a second `PrintLabelPanel.java` in `mms/kp-inventory-client` — this is unrelated (deals with inventory label printing, no WIP/FGS logic).

---

## 4. The `getDefaultLabelType` Method (Lines 746–763)

```java
private LabelType getDefaultLabelType(CorrugatorOrder corrugatorOrder) {
    if (corrugatorOrder != null) {
        try {
            List<StepLite> jobRoute =
                ServiceAccess.getCscService().fetchJobRoute(
                    corrugatorOrder.getJobId(),
                    corrugatorOrder.getCorrugator().getMachineId()
                );
            StepForLabelling nextStepAndMatchOperations =
                RouteHelper.getNextStepAndMatchOperations(
                    1,
                    jobRoute,
                    Arrays.asList(MachineOperation.STRAP, MachineOperation.DELIVER, MachineOperation.STORAGE)
                );
            if (nextStepAndMatchOperations.isHasOperation()) {
                return LabelType.FG;
            }
        }
        catch (CscServiceNotFoundException e) {
            logger.error("...");
        }
    }
    return LabelType.WIP;
}
```

### Logic Summary

1. Fetch the **remaining job route** from step 1 onward (via `CscService.fetchJobRoute`).
2. Walk through the route starting from step 1 looking for specific **terminal operations**: `STRAP`, `DELIVER`, or `STORAGE`.
3. Skip **auto-feedback machines** (machines where `isAutomaticFeedbackMachine() == true`).
4. If a machine with any of those 3 operations is found anywhere in the remaining route → return **FG**.
5. If no such machine found → return **WIP**.

---

## 5. Key Supporting Classes

### 5.1. `RouteHelper.getNextStepAndMatchOperations`
**File:** `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/manufacturing/label/RouteHelper.java`

Key algorithm:
```
For each step (sorted by step number, >= currentStepNumber):
  - Skip steps with no machine
  - If machine has any matching operation → return StepForLabelling(hasOperation=true, stepNumber)
  - If step > currentStepNumber AND machine is NOT auto-feedback → return StepForLabelling(hasOperation=false, stepNumber)
  - (auto-feedback machines are skipped — loop continues to next step)
Return StepForLabelling(hasOperation=false, currentStepNumber)  // nothing found
```

**Key insight:** Auto-feedback machines are **transparently skipped** — they do not terminate the search. Only non-auto-feedback machines matter for labelling purposes. This directly mirrors the Fortran `wip_into_fgs` logic which also skips auto-feedback machines (`no_work_stations == -1 or -2`).

### 5.2. `StepLite`
**File:** `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/pcs/StepLite.java`

Lightweight step representation:
- `jobId` — Long
- `stepNumber` — int
- `manufacturingSetNumber` — String
- `machine` — `Machine` object

### 5.3. `StepForLabelling`
**File:** `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/manufacturing/model/step/StepForLabelling.java`

Simple value object:
- `hasOperation` — boolean (true = found a matching terminal operation → FG)
- `stepNumber` — int (the step where the result was found)

### 5.4. `MachineOperation.PredefinedOperationType`
**File:** `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/manufacturing/model/machines/MachineOperation.java`

Terminal operations used in this determination:
| Operation | Meaning | Fortran Equivalent |
|---|---|---|
| `STRAP` | Strapper/shrinkwrap machine | bits 10/11 of `possible_operation` |
| `DELIVER` | Dispatch / delivery machine | bit 20 of `possible_operation` |
| `STORAGE` | Finished goods store | Implied in Fortran as FGS destination |

### 5.5. `Machine.isAutomaticFeedbackMachine()`
**File:** `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/manufacturing/model/machines/Machine.java`

```java
public boolean isAutomaticFeedbackMachine() {
    if (this.automaticFeedback == null) return false;
    return !MachineAutomaticFeedback.NONE.equals(this.automaticFeedback);
}
```

Maps to: `no_work_stations == -1 or -2` in the Fortran / CSCNTR data (`ctr_num_stations`).

### 5.6. `JobRouteHelper.fetchJobRoute`
**File:** `csc/kp-csc/kp-csc-impl/src/kiwiplan/csc/lineup/JobRouteHelper.java`

Two data sources depending on configuration:
- **Classic PCS** (`isJavaRefreshWithPcsClassic()`): calls `CscLineupEntryAssistant.fetchRemainingRouteForJob(jobId)` — reads from WORKIP/FACTRY database tables.
- **PCS licensed** (`isProductLicenced(KPProduct.PCS)`): calls `CommsService.fetchStepsForJobFromPcs(jobId)` — fetches from the PCS system over comms.
- Corrugator step (step 1) is prepended to the route if remaining steps start from step 2 and `corrugatorMachineId != null`.

---

## 6. Comparison: KP-MapJava vs Fortran `wip_into_fgs`

| Aspect | KP-MapJava (`getDefaultLabelType`) | Fortran `wip_into_fgs` |
|---|---|---|
| **Input** | `CorrugatorOrder` (contains jobId + corrugatorMachineId) | `job_key`, `job_series`, `step_in` |
| **Route source** | `CscService.fetchJobRoute()` — returns `List<StepLite>` with full `Machine` objects | WORKIP table lookup (raw machine numbers) |
| **Auto-feedback skip** | `Machine.isAutomaticFeedbackMachine()` using `MachineAutomaticFeedback` enum | `ctr_num_stations == -1 or -2` |
| **FGS conditions checked** | `STRAP` OR `DELIVER` OR `STORAGE` present in next non-auto step | Dispatch (bit 20), Strapper (bits 10/11), Outside Collation (bits 37+14), Receive+WIP |
| **WIP tracking flag** | Not consulted | XLATEP `SYS/MO` position 66 |
| **Supplier/receive logic** | Not consulted (no bit 28/29 equivalent) | Bits 28, 29 checked |
| **Outside collation** | Not explicitly checked | Bits 37 + 14 both set → FGS |
| **Step iteration** | Walks entire remaining route from step 1 | Loops from `step_in`, incrementing on each auto-feedback/strap step |
| **No PCS DB** | Returns `WIP` (default fallback) | Returns `FGS = 1` (default) |
| **Result type** | `LabelType` enum (WIP or FG) | Integer (0=WIP, 1=FGS) |
| **Context** | GUI label printing (Swing CSC VUE app) | LinkDevice job completion classification |

---

## 7. Assessment: Can It Serve Our Purpose?

### Similarities ✅
- **Same core concept**: both classify based on whether the next significant machine step has a "finishing" operation (strap/deliver/storage = FGS).
- **Auto-feedback skipping**: both skip auto-feedback machines the same way.
- **Route-based logic**: both walk the job route forward from a starting step.
- **DELIVER/dispatch = FGS**: both treat a dispatch/delivery machine as FGS.
- **STRAP = FGS**: both treat a strapper machine as FGS.

### Differences ⚠️
- **KP-MapJava uses richer `Machine` objects** (fully populated, with operation type enums), while Fortran/LinkDevice works with raw bit-pattern integers from CSCNTR.
- **KP-MapJava does NOT check**: WIP tracking flag (XLATEP), supplier operations (bits 28/29), Outside Collation (bits 37+14), or the `no_work_stations` value directly — it relies on `Machine.isAutomaticFeedbackMachine()` which encapsulates that.
- **KP-MapJava starts from step 1** (corrugator step), whereas Fortran uses `step_in` as a configurable starting point.
- **KP-MapJava fetches a full route list** in one call; Fortran looks up one step at a time.
- **STORAGE operation** is treated as FGS in KP-MapJava but has no direct equivalent in the Fortran bit flags documented.

### Key Conclusion
The KP-MapJava implementation **is a simplified and cleaner version of the same concept**, operating at a higher abstraction level (named operation types vs raw bit flags). It covers the main FGS cases (strap, deliver) but does not cover all edge cases that the Fortran `wip_into_fgs` does (WIP tracking, supplier receive, outside collation).

**For the LinkDevice implementation of ADO 923969:**
- The KP-MapJava logic is a **useful reference** for the overall approach.
- The `RouteHelper` + `Machine.isAutomaticFeedbackMachine()` pattern **directly maps** to what LinkDevice needs to implement.
- LinkDevice should implement the **full Fortran logic** (including WIP tracking, supplier, outside collation bits) for correctness — not just the simplified KP-MapJava version.
- However, the `fetchJobRoute` → walk steps approach from KP-MapJava can **replace the step-by-step API call loop** proposed in the spike, if LinkCentral can return the full route in one call rather than per-step.

---

## 8. Alternative Implementation Path (Based on KP-MapJava Pattern)

Instead of the per-step API call loop proposed in the spike, a single-call approach is possible:

```
LinkDevice  →  GET /api/v1/jobs/{jobNumber}/series/{seriesNumber}/route-data
                    ↓
           Returns full List<StepData> with machine capabilities per step
                    ↓
LinkDevice  →  Walks steps using RouteHelper-equivalent logic
                    →  Returns WIP or FGS
```

**Pros:** Single API call per job completion instead of 2-5 calls.  
**Cons:** Returns more data per call; requires new endpoint design.

This is an option worth discussing with the TL — the spike currently proposes per-step calls, but the KP-MapJava pattern suggests the full route batch approach may be cleaner.

---

## 9. Files Investigated

| File | Purpose |
|---|---|
| `csc/kp-csc-gui/src/kiwiplan/csc/gui/panels/PrintLabelPanel.java` | Main file — contains `getDefaultLabelType()` |
| `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/manufacturing/label/RouteHelper.java` | Route walking logic |
| `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/manufacturing/model/machines/MachineOperation.java` | Operation type definitions (STRAP, DELIVER, STORAGE, etc.) |
| `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/manufacturing/model/step/StepForLabelling.java` | Result DTO |
| `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/pcs/StepLite.java` | Lightweight step + machine DTO |
| `manufacturing/kp-manufacturing/kp-manufacturing-api/src/kiwiplan/manufacturing/model/machines/Machine.java` | Machine model — `isAutomaticFeedbackMachine()`, `getOperationTypes()` |
| `csc/kp-csc/kp-csc-impl/src/kiwiplan/csc/lineup/JobRouteHelper.java` | `fetchJobRoute()` — reads from WORKIP/FACTRY (classic) or PCS comms |

---

*Investigation completed: April 21, 2026*  
*Investigated by: Laks Yalamati*

