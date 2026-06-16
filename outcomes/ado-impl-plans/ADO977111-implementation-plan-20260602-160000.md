# CSC Setup API

**ADO Work Item:** [#977111](https://dev.azure.com/advantive-devops/0e254f90-a87c-479e-abde-680deb67b476/_workitems/edit/977111)
**Date:** 2026-06-02
**Assigned To:** Laks Yalamati
**Sprint:** 26.2 Sprint 4
**Repository:** KP-MapJava — `/home/laksyalamat/projects/KP-MapJava`
**Module:** `csc/kp-csc/kp-csc-service`
**Java Version:** 11
**Research Doc:** [ADO977111-research-20260602-145844.md](../research/ADO977111-research-20260602-145844.md)

---

## Summary

- **Tasks:** 10
- **Files changed:** 11
- **New tests:** 4
- **Backward compatible:** Yes (additive only)
- **Version bump required:** No

---

## Context

The CSC (Corrugator Supervisor Controller) REST service currently exposes three API categories — Lineup, Current Run, and Feedback. This work item extends the API by adding two new endpoints under `GET /api/v1/corrugators/{corrugatorName}/setups/{setupNumber}` and `PATCH /api/v1/corrugators/{corrugatorName}/setups/{setupNumber}`. These endpoints expose corrugator setup details to the NLA (New Link Architecture) consumers (BHS DryEnd 4.2.5), following the same bottom-up layered pattern already established in `CorrugatorOrderController` and `CorrugatorSetupLineupController`. The payload shape is derived from the BHS P02 download setup details Groovy template, which defines the canonical field set expected by the corrugator controller hardware.

---

## Data Flow

```mermaid
flowchart LR
    A[HTTP GET /setups/{setupNumber}] --> B[CorrugatorSetupController]
    B --> C[CorrugatorSetupService]
    C --> D1[CscService.getCorrugatorsByName]
    C --> D2[CscService.getSetupRunBySetupNumber]
    D1 --> E[Corrugator domain model]
    D2 --> F[SetupRun domain model]
    E --> G[CorrugatorSetupMapper]
    F --> G
    G --> H[CorrugatorSetupDTO / KnifeSetupDTO]
    H --> B
    B --> I[HTTP 200 JSON Response]

    J[HTTP PATCH /setups/{setupNumber}] --> K[CorrugatorSetupController]
    K --> L[CorrugatorSetupService.updateSetup]
    L --> D1
    L --> D2
    L --> M[Apply CorrugatorSetupUpdateDTO fields to SetupRun]
    M --> N[CscService.storeSetupRun / update]
    N --> G
    G --> O[HTTP 200 JSON Response]
```

---

## Files Changed

| # | File | Change Type | Layer |
|---|---|---|---|
| 1 | `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/CorrugatorSetupDTO.java` | Add | DTO |
| 2 | `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/KnifeSetupDTO.java` | Add | DTO |
| 3 | `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/CorrugatorSetupUpdateDTO.java` | Add | DTO |
| 4 | `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorSetupMapper.java` | Add | Service/Mapper |
| 5 | `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorSetupService.java` | Add | Service |
| 6 | `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/controller/v1/CorrugatorSetupController.java` | Add | Controller |
| 7 | `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/config/auth/CscAuthenticationPatternConfigurator.java` | Modify | Config |
| 8 | `csc/kp-csc/kp-csc-service/doc/corrugator_setup_api.yaml` | Add | Spec |
| 9 | `csc/kp-csc/kp-csc-service/testsrc/com/kiwiplan/csc/rest/service/TestCorrugatorSetupService.java` | Add | Test |
| 10 | `csc/kp-csc/kp-csc-service/testsrc/com/kiwiplan/csc/rest/service/TestCorrugatorSetupMapper.java` | Add | Test |
| 11 | `csc/kp-csc/kp-csc-service/testsrc/com/kiwiplan/csc/rest/controller/v1/TestCorrugatorSetupController.java` | Add | Test |

---

## Tasks

### Task 1 — Add `CorrugatorSetupDTO` (GET response body)

**File:** `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/CorrugatorSetupDTO.java`
**Change type:** Add

#### What to change

Create a new DTO class representing the full response body for `GET /api/v1/corrugators/{corrugatorName}/setups/{setupNumber}`. Fields are derived directly from the BHS P02 Groovy template (top-level setup fields).

#### Why

The GET endpoint must serialise setup details as JSON to NLA consumers. The field set maps to BHS P02 command fields consumed by BHS DryEnd 4.2.5.

#### Code

```java
/**
 * Copyright 2026, Kiwiplan (NZ) Ltd
 */
package com.kiwiplan.csc.rest.dto;

import java.util.List;

/**
 * DTO representing the full details of a corrugator setup.
 * Field names and units follow the BHS P02 download setup details protocol.
 */
public class CorrugatorSetupDTO {

    private Integer setupNumber;
    private String corrugatorName;
    private String setupIdentifier;       // from SetupRun controller ID, BHS: "selected_lineup_element_pair.getControllerId()"
    private Integer webWidth;             // Ten Micron
    private Integer edgeTrimming;         // Ten Micron (setup_trim / 2)
    private String boardGrade;            // board_name
    private String fluteType;             // board_flute_name_cross_section (nullable, BHS 4.2.5 only)
    private Boolean whiteTop;             // white_top (nullable, BHS 4.2.5 only)
    private Boolean waterproofStarch;     // waterproof_starch (nullable, BHS 4.2.5 only)
    private Long scheduledLineal;         // setup_estimated_lineal, Millimetre
    private Integer boardThickness;       // board_thickness, Micron
    private Integer speedOnOrderChange;   // board_run_speed(order_change), mm/min
    private Integer speedAfterOrderChange;// board_run_speed(after_order_change), mm/min
    private List<KnifeSetupDTO> knives;

    public CorrugatorSetupDTO() {
    }

    public Integer getSetupNumber() { return setupNumber; }
    public void setSetupNumber(Integer setupNumber) { this.setupNumber = setupNumber; }

    public String getCorrugatorName() { return corrugatorName; }
    public void setCorrugatorName(String corrugatorName) { this.corrugatorName = corrugatorName; }

    public String getSetupIdentifier() { return setupIdentifier; }
    public void setSetupIdentifier(String setupIdentifier) { this.setupIdentifier = setupIdentifier; }

    public Integer getWebWidth() { return webWidth; }
    public void setWebWidth(Integer webWidth) { this.webWidth = webWidth; }

    public Integer getEdgeTrimming() { return edgeTrimming; }
    public void setEdgeTrimming(Integer edgeTrimming) { this.edgeTrimming = edgeTrimming; }

    public String getBoardGrade() { return boardGrade; }
    public void setBoardGrade(String boardGrade) { this.boardGrade = boardGrade; }

    public String getFluteType() { return fluteType; }
    public void setFluteType(String fluteType) { this.fluteType = fluteType; }

    public Boolean getWhiteTop() { return whiteTop; }
    public void setWhiteTop(Boolean whiteTop) { this.whiteTop = whiteTop; }

    public Boolean getWaterproofStarch() { return waterproofStarch; }
    public void setWaterproofStarch(Boolean waterproofStarch) { this.waterproofStarch = waterproofStarch; }

    public Long getScheduledLineal() { return scheduledLineal; }
    public void setScheduledLineal(Long scheduledLineal) { this.scheduledLineal = scheduledLineal; }

    public Integer getBoardThickness() { return boardThickness; }
    public void setBoardThickness(Integer boardThickness) { this.boardThickness = boardThickness; }

    public Integer getSpeedOnOrderChange() { return speedOnOrderChange; }
    public void setSpeedOnOrderChange(Integer speedOnOrderChange) { this.speedOnOrderChange = speedOnOrderChange; }

    public Integer getSpeedAfterOrderChange() { return speedAfterOrderChange; }
    public void setSpeedAfterOrderChange(Integer speedAfterOrderChange) { this.speedAfterOrderChange = speedAfterOrderChange; }

    public List<KnifeSetupDTO> getKnives() { return knives; }
    public void setKnives(List<KnifeSetupDTO> knives) { this.knives = knives; }
}
```

#### Notes

- All nullable fields (`fluteType`, `whiteTop`, `waterproofStarch`) must be serialised as JSON `null` — do not default to `""` or `false`.
- `webWidth` and `edgeTrimming` are in Ten Micron — no unit conversion in the DTO; document units in the API YAML.
- `scheduledLineal` is `Long` (millimetres can overflow `Integer` for long runs).

---

### Task 2 — Add `KnifeSetupDTO` (per-knife setup data)

**File:** `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/KnifeSetupDTO.java`
**Change type:** Add

#### What to change

Create a new DTO class for per-knife setup data, embedded in `CorrugatorSetupDTO.knives`. Fields map to the BHS P02 knife-include template.

#### Why

BHS DryEnd requires per-knife order details as part of the setup payload (order number, customer name, sheet length, stack height, score positions).

#### Code

```java
/**
 * Copyright 2026, Kiwiplan (NZ) Ltd
 */
package com.kiwiplan.csc.rest.dto;

import java.util.List;

/**
 * DTO representing per-knife order and dimension details within a corrugator setup.
 * Field units follow the BHS P02 knife-include template.
 */
public class KnifeSetupDTO {

    private Integer knifeNumber;
    private String orderNumber;           // datum.order_number
    private String customerName;          // datum.order_customer_name
    private String nextMachine;           // datum.next_machine
    private Integer destinationLine;      // BHS 4.2.5 only — literal 0
    private Integer estimatedCuts;        // datum.knife_estimated_cuts
    private Integer numberOfOuts;         // datum.out_sequence_number_outs
    private Integer sheetLength;          // datum.knife_board_length, Ten Micron
    private Integer stackHeight;          // datum.knife_sheets_per_stack
    private List<Integer> scores;         // relative score positions, Ten Micron (per knife)
    private List<Integer> scoreTypeIndexes; // BHS 4.2.5 only, nullable

    public KnifeSetupDTO() {
    }

    public Integer getKnifeNumber() { return knifeNumber; }
    public void setKnifeNumber(Integer knifeNumber) { this.knifeNumber = knifeNumber; }

    public String getOrderNumber() { return orderNumber; }
    public void setOrderNumber(String orderNumber) { this.orderNumber = orderNumber; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public String getNextMachine() { return nextMachine; }
    public void setNextMachine(String nextMachine) { this.nextMachine = nextMachine; }

    public Integer getDestinationLine() { return destinationLine; }
    public void setDestinationLine(Integer destinationLine) { this.destinationLine = destinationLine; }

    public Integer getEstimatedCuts() { return estimatedCuts; }
    public void setEstimatedCuts(Integer estimatedCuts) { this.estimatedCuts = estimatedCuts; }

    public Integer getNumberOfOuts() { return numberOfOuts; }
    public void setNumberOfOuts(Integer numberOfOuts) { this.numberOfOuts = numberOfOuts; }

    public Integer getSheetLength() { return sheetLength; }
    public void setSheetLength(Integer sheetLength) { this.sheetLength = sheetLength; }

    public Integer getStackHeight() { return stackHeight; }
    public void setStackHeight(Integer stackHeight) { this.stackHeight = stackHeight; }

    public List<Integer> getScores() { return scores; }
    public void setScores(List<Integer> scores) { this.scores = scores; }

    public List<Integer> getScoreTypeIndexes() { return scoreTypeIndexes; }
    public void setScoreTypeIndexes(List<Integer> scoreTypeIndexes) { this.scoreTypeIndexes = scoreTypeIndexes; }
}
```

#### Notes

- `scores` and `scoreTypeIndexes` are lists with one element per score position. May be empty (not null) when no score data is available.
- `destinationLine` always returns `0` in BHS 4.2.5 environment — this is a protocol requirement, not domain data.
- `scoreTypeIndexes` is nullable at the DTO level (only populated for BHS 4.2.5 endpoints).

---

### Task 3 — Add `CorrugatorSetupUpdateDTO` (PATCH request body)

**File:** `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/CorrugatorSetupUpdateDTO.java`
**Change type:** Add

#### What to change

Create a DTO for the PATCH request body. All fields are optional (nullable) — only fields present in the JSON payload are applied. This mirrors the `CorrugatorOrderQuantityUpdateDTO` PATCH pattern.

#### Why

The PATCH endpoint must accept partial updates. Only mutable setup fields should be exposed. The knowledge base docs define which setup parameters are writable (primarily speed settings, prewarn distance, controller parameters).

#### Code

```java
/**
 * Copyright 2026, Kiwiplan (NZ) Ltd
 */
package com.kiwiplan.csc.rest.dto;

/**
 * Request body DTO for PATCH /api/v1/corrugators/{corrugatorName}/setups/{setupNumber}.
 * All fields are optional; only non-null fields are applied to the existing setup.
 */
public class CorrugatorSetupUpdateDTO {

    private Integer speedOnOrderChange;    // mm/min — writable
    private Integer speedAfterOrderChange; // mm/min — writable
    private Integer prewarnDistance;       // Ten Micron — writable (CSC/OP parameter: Prewarn distance)
    private Boolean whiteTop;             // writable (BHS 4.2.5)
    private Boolean waterproofStarch;     // writable (BHS 4.2.5)

    public CorrugatorSetupUpdateDTO() {
    }

    public Integer getSpeedOnOrderChange() { return speedOnOrderChange; }
    public void setSpeedOnOrderChange(Integer speedOnOrderChange) { this.speedOnOrderChange = speedOnOrderChange; }

    public Integer getSpeedAfterOrderChange() { return speedAfterOrderChange; }
    public void setSpeedAfterOrderChange(Integer speedAfterOrderChange) { this.speedAfterOrderChange = speedAfterOrderChange; }

    public Integer getPrewarnDistance() { return prewarnDistance; }
    public void setPrewarnDistance(Integer prewarnDistance) { this.prewarnDistance = prewarnDistance; }

    public Boolean getWhiteTop() { return whiteTop; }
    public void setWhiteTop(Boolean whiteTop) { this.whiteTop = whiteTop; }

    public Boolean getWaterproofStarch() { return waterproofStarch; }
    public void setWaterproofStarch(Boolean waterproofStarch) { this.waterproofStarch = waterproofStarch; }
}
```

#### Notes

- Fields must remain nullable — Jackson will leave them as `null` if absent from the payload, which is the intended partial-update signal.
- Do **not** add `@NotNull` or `@Min` constraints on update DTO fields. Constraint annotation would make all fields mandatory.
- **Important:** The exact set of writable fields must be confirmed against `vue-csc-business-logics-in-xml-contracts.md` (KnowledgeBase) before final implementation. The fields listed here are the most likely writable candidates based on BHS template analysis. Extend or trim accordingly.

---

### Task 4 — Add `CorrugatorSetupMapper` (domain → DTO transformation)

**File:** `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorSetupMapper.java`
**Change type:** Add

#### What to change

Create a pure `@Component` mapper that transforms `SetupRun` + `Corrugator` domain objects into `CorrugatorSetupDTO`. Mirror the style of `CorrugatorSetupLineupMapper` — no data access, no business logic.

#### Why

Separating mapping from service logic follows the existing single-responsibility pattern in the module and makes the mapper independently testable.

#### Code

```java
/**
 * Copyright 2026, Kiwiplan (NZ) Ltd
 */
package com.kiwiplan.csc.rest.service;

import com.kiwiplan.csc.rest.dto.CorrugatorSetupDTO;
import com.kiwiplan.csc.rest.dto.KnifeSetupDTO;
import kiwiplan.csc.model.corrugators.Corrugator;
import kiwiplan.csc.model.orders.CorrugatorOrder;
import kiwiplan.csc.model.setups.SetupKnife;
import kiwiplan.csc.model.setups.SetupRun;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Pure mapper component: transforms SetupRun domain objects to CorrugatorSetupDTO.
 * No data access or business logic — transformation only.
 * <p>
 * Copyright 2026, Kiwiplan (NZ) Ltd.
 */
@Component
public class CorrugatorSetupMapper {

    /**
     * Maps a SetupRun and its owning Corrugator to a CorrugatorSetupDTO.
     *
     * @param setupRun      the setup run domain object (must not be null)
     * @param corrugator    the corrugator domain object (must not be null)
     * @return the populated CorrugatorSetupDTO
     */
    public CorrugatorSetupDTO toDTO(SetupRun setupRun, Corrugator corrugator) {
        CorrugatorSetupDTO dto = new CorrugatorSetupDTO();

        dto.setSetupNumber(setupRun.getSetupNumber());
        dto.setCorrugatorName(corrugator.getName());
        // NOTE: SetupRun does not have a direct getControllerId().
        // Verify via: does WetendRun or SetupConfiguration expose a controllerId?
        // Placeholder: dto.setSetupIdentifier(setupRun.getWetendRun().getControllerId());

        // Wetend roll width: accessed via WetendRun → WetendConfiguration → getRollWidth() (returns Lineal)
        // Confirmed navigation: setupRun.getWetendRun().getWetendConfiguration().getRollWidth()
        // Convert Lineal to Ten Micron integer: rollWidth.getDoubleAmount(Lineal.TEN_MICRON).intValue()
        // NOTE: verify Lineal.TEN_MICRON constant exists; alternative is Lineal.MILLIMETRE / 10
        // Guard for null WetendRun:
        if (setupRun.getWetendRun() != null
                && setupRun.getWetendRun().getWetendConfiguration() != null
                && setupRun.getWetendRun().getWetendConfiguration().getRollWidth() != null) {
            Lineal rollWidth = setupRun.getWetendRun().getWetendConfiguration().getRollWidth();
            // TODO: confirm unit constant; use Lineal.CENTIMETRE or Lineal.MILLIMETRE as fallback
            dto.setWebWidth((int) (rollWidth.getDoubleAmount(Lineal.MILLIMETRE) * 100)); // mm → Ten Micron
        }

        // Edge trimming: setupConfiguration.getWidth() minus used web width, divided by 2
        // Access via: setupRun.getEstimatedTrimWaste() (returns Area) — not directly Ten Micron.
        // The Groovy template uses: datum.setup_trim().divideBy(2F)
        // Confirm exact computation with domain team. Placeholder approach below:
        // Lineal calculatedTrim = setupRun.getSetupConfiguration().getWidth().minusLineal(usedWebWidth);
        // dto.setEdgeTrimming((int)(calculatedTrim.getDoubleAmount(Lineal.MILLIMETRE) * 100) / 2);
        // TODO: implement after domain field investigation

        // Board grade: via setupRun.getBoard() → MaterialType.getName()
        if (setupRun.getBoard() != null) {
            dto.setBoardGrade(setupRun.getBoard().getName());
            // Flute type: MaterialType (board) likely has getFluteTypeName() or similar
            // TODO: confirm exact getter on MaterialType for flute cross-section name
        }

        // whiteTop, waterproofStarch: these are likely on SetupConfiguration or WetendRun.
        // TODO: confirm exact object path. Check:
        //   setupRun.getSetupConfiguration() for boolean flags
        //   setupRun.getWetendRun().getWetendConfiguration() for starch type

        // Scheduled lineal: setupRun.getTotalEstimatedLength() returns Lineal
        if (setupRun.getTotalEstimatedLength() != null) {
            // Convert to millimetres (Long)
            dto.setScheduledLineal((long) setupRun.getTotalEstimatedLength().getDoubleAmount(Lineal.MILLIMETRE));
        }

        // Board thickness, speeds: these are on SetupConfiguration or MaterialType.
        // TODO: confirm by reading SetupConfiguration.java:
        //   grep -n "getThickness\|getRunSpeed\|getSpeed\|getBoardThick" SetupConfiguration.java

        // Map knife-level data using confirmed method: setupRun.getSetupKnives()
        List<SetupKnife> knives = setupRun.getSetupKnives();
        if (knives != null && !knives.isEmpty()) {
            List<KnifeSetupDTO> knifeDTOs = new ArrayList<>();
            for (SetupKnife knife : knives) {
                knifeDTOs.add(toKnifeDTO(knife));
            }
            dto.setKnives(knifeDTOs);
        } else {
            dto.setKnives(Collections.emptyList());
        }

        return dto;
    }

    /**
     * Maps a single SetupKnife to a KnifeSetupDTO.
     *
     * @param knife the setup knife domain object
     * @return the populated KnifeSetupDTO
     */
    public KnifeSetupDTO toKnifeDTO(SetupKnife knife) {
        KnifeSetupDTO dto = new KnifeSetupDTO();

        // Knife number: via SetupKnife.getKnife() → CorrugatorKnife.getKnifeNumber()
        // Confirmed navigation from SetupKnife source: knife.getKnife() returns CorrugatorKnife
        if (knife.getKnife() != null) {
            // TODO: confirm CorrugatorKnife getter name for knife number
            // dto.setKnifeNumber(knife.getKnife().getKnifeNumber());
        }

        // Order data: SetupKnife.getSetupOrder().getCorrugatorOrder() (confirmed from SetupKnife source)
        if (knife.getSetupOrder() != null && knife.getSetupOrder().getCorrugatorOrder() != null) {
            CorrugatorOrder order = knife.getSetupOrder().getCorrugatorOrder();
            dto.setOrderNumber(order.getOrderNumber());
            // TODO: confirm CorrugatorOrder has getCustomerName() and getNextMachine()
            // dto.setCustomerName(order.getCustomerName());
            // dto.setNextMachine(order.getNextMachine());
        }

        dto.setDestinationLine(0); // Protocol requirement: always 0 in BHS 4.2.5

        // Estimated cuts: TODO confirm getter — may be on SetupOrder or computed
        // dto.setEstimatedCuts(knife.getEstimatedCuts());

        // Number of outs: CONFIRMED — SetupKnife.getNumberOut() (int)
        dto.setNumberOfOuts(knife.getNumberOut());

        // Sheet length: CONFIRMED — SetupKnife.getOrderedBoardLength() returns Lineal
        // Convert to Ten Micron: (int)(length.getDoubleAmount(Lineal.MILLIMETRE) * 100)
        if (knife.getOrderedBoardLength() != null) {
            dto.setSheetLength((int) (knife.getOrderedBoardLength().getDoubleAmount(Lineal.MILLIMETRE) * 100));
        }

        // Stack height: CONFIRMED — SetupKnife.getSheetsPerStack() returns Integer
        dto.setStackHeight(knife.getSheetsPerStack());

        // Score positions: CONFIRMED — SetupKnife.getScoreSet() → ScoreSet
        // TODO: extract integer positions from ScoreSet:
        //   ScoreSet has getScores() or similar; each Score has a position (Lineal)
        //   Convert each to Ten Micron integer
        // ScoreSet scoreSet = knife.getScoreSet();
        // if (scoreSet != null) { ... }

        return dto;
    }
}
```

#### Notes

- **Field names on `SetupRun` and `SetupKnife` must be verified** against the actual model before implementation. The names used here (`getWebWidth()`, `getSetupTrim()`, `getBoardName()`, etc.) are inferred from the BHS Groovy template — confirm the exact Java getter names by reading `SetupRun.java` and `SetupKnife.java` in the model layer.
- Null guard every domain field that could be absent for older setup records.
- For `Collections.emptyList()` — use `java.util.Collections` (Java 11 compatible).

---

### Task 5 — Add `CorrugatorSetupService` (orchestration)

**File:** `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorSetupService.java`
**Change type:** Add

#### What to change

Create an `@Service` class responsible for:
1. Looking up a corrugator by name (new helper method `getActiveCorrugatorByName`).
2. Fetching a `SetupRun` by corrugator ID + setup number.
3. Delegating DTO construction to `CorrugatorSetupMapper`.
4. Validating and applying PATCH updates.

Mirror the structure of `CorrugatorSetupLineupService`.

#### Why

The service layer encapsulates all business logic and exception translation, keeping the controller thin and testable.

#### Code

```java
/**
 * Copyright 2026, Kiwiplan (NZ) Ltd
 */
package com.kiwiplan.csc.rest.service;

import com.kiwiplan.csc.rest.dto.CorrugatorSetupDTO;
import com.kiwiplan.csc.rest.dto.CorrugatorSetupUpdateDTO;
import com.kiwiplan.csc.rest.exception.CorrugatorNotFoundException;
import com.kiwiplan.csc.rest.exception.CorrugatorSetupNotFoundException;
import kiwiplan.csc.model.corrugators.Corrugator;
import kiwiplan.csc.model.setups.SetupRun;
import kiwiplan.csc.model.setups.SetupStatus;
import kiwiplan.csc.service.CscService;
import kiwiplan.csc.service.CscServiceException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;

/**
 * Orchestration service for corrugator setup GET and PATCH operations.
 * Coordinates corrugator lookup, setup retrieval, update application, and DTO mapping.
 * <p>
 * Copyright 2026, Kiwiplan (NZ) Ltd.
 */
@Service
public class CorrugatorSetupService {

    private static final Logger logger = LoggerFactory.getLogger(CorrugatorSetupService.class);

    private static final List<SetupStatus> ACTIVE_SETUP_STATUSES = Arrays.asList(
            SetupStatus.ISSUED,
            SetupStatus.PROCESSING
    );

    private final CscService cscService;
    private final CorrugatorSetupMapper mapper;

    public CorrugatorSetupService(CscService cscService, CorrugatorSetupMapper mapper) {
        this.cscService = cscService;
        this.mapper = mapper;
    }

    /**
     * Retrieves a corrugator by name, excluding retired corrugators.
     * Uses CscService.getCorrugatorsByName, filters out retired, returns the first match.
     *
     * @param corrugatorName the corrugator name from the API path variable
     * @return the active Corrugator
     * @throws CorrugatorNotFoundException if no active corrugator exists with the given name
     * @throws CscServiceException if a data access error occurs
     */
    public Corrugator getActiveCorrugatorByName(String corrugatorName)
            throws CorrugatorNotFoundException, CscServiceException {
        List<Corrugator> corrugators = cscService.getCorrugatorsByName(corrugatorName);
        if (corrugators == null || corrugators.isEmpty()) {
            throw new CorrugatorNotFoundException(
                    String.format("Corrugator with name '%s' not found.", corrugatorName));
        }
        return corrugators.stream()
                .filter(c -> !c.isRetired())
                .findFirst()
                .orElseThrow(() -> new CorrugatorNotFoundException(
                        String.format("Corrugator with name '%s' not found or is retired.", corrugatorName)));
    }

    /**
     * Fetches setup details for the given corrugator ID and setup number.
     *
     * @param corrugator  the active corrugator
     * @param setupNumber the setup number from the API path variable
     * @return the populated CorrugatorSetupDTO
     * @throws CorrugatorSetupNotFoundException if no matching setup is found
     * @throws CscServiceException if a data access error occurs
     */
    public CorrugatorSetupDTO fetchSetupDetails(Corrugator corrugator, Integer setupNumber)
            throws CorrugatorSetupNotFoundException, CscServiceException {
        try {
            SetupRun setupRun = cscService.getSetupRunBySetupNumber(
                    corrugator.getId(), setupNumber, ACTIVE_SETUP_STATUSES);
            if (setupRun == null) {
                throw new CorrugatorSetupNotFoundException(
                        String.format("Setup '%d' not found for corrugator '%s'.",
                                setupNumber, corrugator.getName()));
            }
            return mapper.toDTO(setupRun, corrugator);
        } catch (CorrugatorSetupNotFoundException e) {
            throw e;
        } catch (Exception e) {
            if (logger.isErrorEnabled()) {
                logger.error("Error fetching setup {} for corrugator {}", setupNumber, corrugator.getName(), e);
            }
            throw new CscServiceException(e);
        }
    }

    /**
     * Applies mutable fields from the update DTO to the existing setup and persists the change.
     * Only non-null fields in the update DTO are applied (partial update / PATCH semantics).
     *
     * @param corrugator  the active corrugator
     * @param setupNumber the setup number
     * @param updateDTO   the PATCH request body
     * @return the updated CorrugatorSetupDTO
     * @throws CorrugatorSetupNotFoundException if setup does not exist
     * @throws CscServiceException if a data access or persistence error occurs
     */
    public CorrugatorSetupDTO updateSetup(Corrugator corrugator, Integer setupNumber,
                                          CorrugatorSetupUpdateDTO updateDTO)
            throws CorrugatorSetupNotFoundException, CscServiceException {
        try {
            SetupRun setupRun = cscService.getSetupRunBySetupNumber(
                    corrugator.getId(), setupNumber, ACTIVE_SETUP_STATUSES);
            if (setupRun == null) {
                throw new CorrugatorSetupNotFoundException(
                        String.format("Setup '%d' not found for corrugator '%s'.",
                                setupNumber, corrugator.getName()));
            }

            // Apply partial update — only non-null fields
            if (updateDTO.getSpeedOnOrderChange() != null) {
                setupRun.setRunSpeedOnOrderChange(updateDTO.getSpeedOnOrderChange());
            }
            if (updateDTO.getSpeedAfterOrderChange() != null) {
                setupRun.setRunSpeedAfterOrderChange(updateDTO.getSpeedAfterOrderChange());
            }
            if (updateDTO.getPrewarnDistance() != null) {
                setupRun.setPrewarnDistance(updateDTO.getPrewarnDistance());
            }
            if (updateDTO.getWhiteTop() != null) {
                setupRun.setWhiteTop(updateDTO.getWhiteTop());
            }
            if (updateDTO.getWaterproofStarch() != null) {
                setupRun.setWaterproofStarch(updateDTO.getWaterproofStarch());
            }

            // CONFIRMED: CscService does NOT have a bare storeSetupRun(SetupRun) method.
            // Available options:
            //   storeSetupRunAndSetupConfiguration(SetupRun) — throws CscServiceException, SetupInProtectedRegionException
            //   storeSetupRuns(List<SetupRun>)               — bulk, void
            // Use storeSetupRunAndSetupConfiguration for single-setup PATCH:
            try {
                cscService.storeSetupRunAndSetupConfiguration(setupRun);
            } catch (SetupInProtectedRegionException e) {
                throw new CscServiceException(e);
            }
            // TODO: import kiwiplan.csc.service.exception.SetupInProtectedRegionException

            return mapper.toDTO(setupRun, corrugator);
        } catch (CorrugatorSetupNotFoundException e) {
            throw e;
        } catch (Exception e) {
            if (logger.isErrorEnabled()) {
                logger.error("Error updating setup {} for corrugator {}", setupNumber, corrugator.getName(), e);
            }
            throw new CscServiceException(e);
        }
    }
}
```

#### Notes

- `getActiveCorrugatorByName()` uses `getCorrugatorsByName()` (Java stream filter — Java 11 compatible using `.stream().filter(...).findFirst()`).
- `ACTIVE_SETUP_STATUSES` — confirm whether `SetupStatus.FINISHED` or `SetupStatus.RETURNED` also need to be included for the GET endpoint (BHS requests setup details for setups that may have recently completed). If GET should also return historical setups, expand the status list.
- **`storeSetupRunAndSetupConfiguration(SetupRun)`** is the confirmed persist method. It also throws `SetupInProtectedRegionException` — catch and wrap as `CscServiceException` in the service layer.
- The setter method names on `SetupRun` for speeds (`setRunSpeedOnOrderChange`, etc.) still need confirming — run `grep -n "setRunSpeed\|setPrewarn\|setWhiteTop\|setWaterproof\|setSpeed"` on `SetupRun.java` and `SetupConfiguration.java`. Speed fields may be on `SetupConfiguration` rather than `SetupRun` itself.

---

### Task 6 — Add `CorrugatorSetupController`

**File:** `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/controller/v1/CorrugatorSetupController.java`
**Change type:** Add

#### What to change

Create a new `@RestController` implementing:
- `GET /api/v1/corrugators/{corrugatorName}/setups/{setupNumber}` → returns `ResponseEntity<CorrugatorSetupDTO>`
- `PATCH /api/v1/corrugators/{corrugatorName}/setups/{setupNumber}` → accepts `@RequestBody CorrugatorSetupUpdateDTO`, returns `ResponseEntity<CorrugatorSetupDTO>`

Follow `CorrugatorSetupLineupController` for structure (constructor injection, `@Validated`, Swagger annotations, OAuth2 security requirements).

#### Why

The controller is the HTTP entry point that delegates to the service, handles path variables, and translates service results to `ResponseEntity`.

#### Code

```java
/**
 * Copyright 2026, Kiwiplan (NZ) Ltd
 */
package com.kiwiplan.csc.rest.controller.v1;

import com.kiwiplan.csc.rest.dto.CorrugatorSetupDTO;
import com.kiwiplan.csc.rest.dto.CorrugatorSetupUpdateDTO;
import com.kiwiplan.csc.rest.exception.CorrugatorNotFoundException;
import com.kiwiplan.csc.rest.exception.CorrugatorSetupNotFoundException;
import com.kiwiplan.csc.rest.service.CorrugatorSetupService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import kiwiplan.csc.model.corrugators.Corrugator;
import kiwiplan.csc.service.CscServiceException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.validation.Valid;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;

/**
 * REST API controller for Corrugator Setup GET and PATCH operations.
 * <p>
 * Copyright 2026, Kiwiplan (NZ) Ltd.
 */
@Tag(description = "Corrugator Setup API", name = "Corrugator Setup API")
@RestController
@RequestMapping("/api/v1")
@Validated
public class CorrugatorSetupController {

    private static final Logger logger = LoggerFactory.getLogger(CorrugatorSetupController.class);

    private final CorrugatorSetupService setupService;

    @Autowired
    public CorrugatorSetupController(CorrugatorSetupService setupService) {
        this.setupService = setupService;
    }

    @Operation(
            summary = "Get corrugator setup details",
            description = "Retrieve full setup details for a given setup number on the specified corrugator. " +
                          "Returns top-level setup data (board grade, web width, speeds) and per-knife order information.",
            security = @SecurityRequirement(name = "OAuth2", scopes = {"readCorrugatorSetups"})
    )
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Setup details retrieved successfully.",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = CorrugatorSetupDTO.class))),
            @ApiResponse(responseCode = "400", description = "Bad request — invalid or missing parameters.",
                    content = @Content(mediaType = "application/json")),
            @ApiResponse(responseCode = "403", description = "Unauthorized — insufficient permissions.",
                    content = @Content(mediaType = "application/json")),
            @ApiResponse(responseCode = "404", description = "Not found — corrugator or setup not found.",
                    content = @Content(mediaType = "application/json")),
            @ApiResponse(responseCode = "500", description = "Internal server error.",
                    content = @Content(mediaType = "application/json"))
    })
    @GetMapping("/corrugators/{corrugatorName}/setups/{setupNumber}")
    public ResponseEntity<CorrugatorSetupDTO> getSetupDetails(
            @Parameter(description = "Corrugator name", required = true, example = "CORR-1")
            @PathVariable("corrugatorName") @NotBlank(message = "corrugatorName cannot be empty") String corrugatorName,
            @Parameter(description = "Setup number", required = true, example = "574")
            @PathVariable("setupNumber") @NotNull(message = "setupNumber cannot be null") Integer setupNumber)
            throws CorrugatorNotFoundException, CorrugatorSetupNotFoundException, CscServiceException {

        if (logger.isInfoEnabled()) {
            logger.info("GET setup details for corrugator '{}', setup {}", corrugatorName, setupNumber);
        }

        Corrugator corrugator = setupService.getActiveCorrugatorByName(corrugatorName.trim());
        CorrugatorSetupDTO dto = setupService.fetchSetupDetails(corrugator, setupNumber);
        return ResponseEntity.ok(dto);
    }

    @Operation(
            summary = "Update corrugator setup details",
            description = "Apply partial updates to a corrugator setup. Only non-null fields in the request body are applied.",
            security = @SecurityRequirement(name = "OAuth2", scopes = {"writeCorrugatorSetups"})
    )
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Setup updated successfully.",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = CorrugatorSetupDTO.class))),
            @ApiResponse(responseCode = "400", description = "Bad request — invalid request body.",
                    content = @Content(mediaType = "application/json")),
            @ApiResponse(responseCode = "403", description = "Unauthorized — insufficient permissions.",
                    content = @Content(mediaType = "application/json")),
            @ApiResponse(responseCode = "404", description = "Not found — corrugator or setup not found.",
                    content = @Content(mediaType = "application/json")),
            @ApiResponse(responseCode = "500", description = "Internal server error.",
                    content = @Content(mediaType = "application/json"))
    })
    @PatchMapping("/corrugators/{corrugatorName}/setups/{setupNumber}")
    public ResponseEntity<CorrugatorSetupDTO> updateSetupDetails(
            @Parameter(description = "Corrugator name", required = true, example = "CORR-1")
            @PathVariable("corrugatorName") @NotBlank(message = "corrugatorName cannot be empty") String corrugatorName,
            @Parameter(description = "Setup number", required = true, example = "574")
            @PathVariable("setupNumber") @NotNull(message = "setupNumber cannot be null") Integer setupNumber,
            @Valid @RequestBody CorrugatorSetupUpdateDTO updateDTO)
            throws CorrugatorNotFoundException, CorrugatorSetupNotFoundException, CscServiceException {

        if (logger.isInfoEnabled()) {
            logger.info("PATCH setup {} for corrugator '{}' with update: {}", setupNumber, corrugatorName, updateDTO);
        }

        Corrugator corrugator = setupService.getActiveCorrugatorByName(corrugatorName.trim());
        CorrugatorSetupDTO dto = setupService.updateSetup(corrugator, setupNumber, updateDTO);
        return ResponseEntity.ok(dto);
    }
}
```

#### Notes

- `@NotBlank` requires `javax.validation.constraints.NotBlank` — already present on the classpath (used in `CorrugatorSetupLineupController`).
- `@NotNull` on a path variable `Integer` is correct — Spring will convert the path segment to Integer before validation. If the path segment is not a valid integer, Spring throws a `MethodArgumentTypeMismatchException` (handle in `CscControllerExceptionHandler` if not already handled generically).
- `corrugatorName.trim()` in the controller normalises leading/trailing whitespace consistently with the `corrugatorNumber` normalisation pattern in `CorrugatorSetupLineupController`.

---

### Task 7 — Register new routes in `CscAuthenticationPatternConfigurator`

**File:** `csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/config/auth/CscAuthenticationPatternConfigurator.java`
**Change type:** Modify

#### What to change

Add the two new setup API route patterns to `requestMatchers()` so Spring Security processes them correctly.

#### Why

All API routes must be explicitly listed in `requestMatchers()`. If omitted, Spring Security will fail to match them and may deny or mis-route requests.

#### Code

```java
// Before (existing method body)
@Override
public void requestMatchers(HttpSecurity.RequestMatcherConfigurer requestMatcherConfigurer) {
    requestMatcherConfigurer.mvcMatchers("/swagger-ui.html")
                            .mvcMatchers("/swagger-ui/**")
                            .mvcMatchers("/api/v1/production-data")
                            .mvcMatchers("/api/v1/corrugator-orders/**")
                            .mvcMatchers("/api/v1/corrugators/{corrugatorNumber}")
                            .mvcMatchers("/api/v1/corrugators/{corrugatorNumber}/discharge")
    ;
}

// After — add two new patterns before the closing semicolon
@Override
public void requestMatchers(HttpSecurity.RequestMatcherConfigurer requestMatcherConfigurer) {
    requestMatcherConfigurer.mvcMatchers("/swagger-ui.html")
                            .mvcMatchers("/swagger-ui/**")
                            .mvcMatchers("/api/v1/production-data")
                            .mvcMatchers("/api/v1/corrugator-orders/**")
                            .mvcMatchers("/api/v1/corrugators/{corrugatorNumber}")
                            .mvcMatchers("/api/v1/corrugators/{corrugatorNumber}/discharge")
                            .mvcMatchers("/api/v1/corrugators/{corrugatorName}/setups/{setupNumber}")
    ;
}
```

#### Notes

- Path variable names in `mvcMatchers` patterns are arbitrary — the string literal `{corrugatorName}` and `{corrugatorNumber}` are treated identically by `mvcMatchers` (they are positional wildcards). Use a single pattern covering both GET and PATCH since both use the same path template.
- No separate pattern is needed for GET vs PATCH on the same path.

---

### Task 8 — Add OpenAPI specification `corrugator_setup_api.yaml`

**File:** `csc/kp-csc/kp-csc-service/doc/corrugator_setup_api.yaml`
**Change type:** Add

#### What to change

Create a new OpenAPI 3.0.0 YAML file documenting both new endpoints, following the `corrugator_order_api.yaml` format exactly.

#### Why

All CSC endpoints must have machine-readable OpenAPI documentation in the `doc/` folder. The format is already established by `corrugator_order_api.yaml`.

#### Code

```yaml
openapi: 3.0.0
info:
  title: Corrugator Setup API
  description: API for corrugator setup details in the CSC service.
  version: 1.0.0
paths:
  /api/v1/corrugators/{corrugatorName}/setups/{setupNumber}:
    get:
      summary: Get corrugator setup details
      description: Retrieve full setup details for the given setup number on the specified corrugator.
      security:
        - OAuth2:
            - readCorrugatorSetups
      parameters:
        - name: corrugatorName
          in: path
          required: true
          schema:
            type: string
          example: CORR-1
        - name: setupNumber
          in: path
          required: true
          schema:
            type: integer
          example: 574
      responses:
        '200':
          description: Setup details retrieved successfully.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CorrugatorSetup'
        '400':
          description: Bad request.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorData'
        '403':
          $ref: '#/components/responses/UnauthorizedError'
        '404':
          description: Corrugator or setup not found.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorData'
              examples:
                corrugatorNotFound:
                  summary: Corrugator not found
                  value:
                    error:
                      code: "CORRUGATOR_NOT_FOUND"
                      logMessage: "Corrugator with name 'CORR-1' not found."
                setupNotFound:
                  summary: Setup not found
                  value:
                    error:
                      code: "CORRUGATOR_SETUP_NOT_FOUND"
                      logMessage: "Setup '574' not found for corrugator 'CORR-1'."
        '500':
          $ref: '#/components/responses/InternalServerError'
    patch:
      summary: Update corrugator setup details
      description: Apply partial updates to a corrugator setup. Only non-null fields are applied.
      security:
        - OAuth2:
            - writeCorrugatorSetups
      parameters:
        - name: corrugatorName
          in: path
          required: true
          schema:
            type: string
          example: CORR-1
        - name: setupNumber
          in: path
          required: true
          schema:
            type: integer
          example: 574
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CorrugatorSetupUpdate'
      responses:
        '200':
          description: Setup updated successfully.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CorrugatorSetup'
        '400':
          $ref: '#/components/responses/BadRequestError'
        '403':
          $ref: '#/components/responses/UnauthorizedError'
        '404':
          description: Corrugator or setup not found.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorData'
        '500':
          $ref: '#/components/responses/InternalServerError'

components:
  securitySchemes:
    OAuth2:
      type: oauth2
      flows:
        clientCredentials:
          tokenUrl: /oauth/token
          scopes:
            readCorrugatorSetups: Read corrugator setup details
            writeCorrugatorSetups: Update corrugator setup details

  schemas:
    CorrugatorSetup:
      type: object
      properties:
        setupNumber:
          type: integer
          description: Setup number (legacy program number)
        corrugatorName:
          type: string
          description: Name of the corrugator
        setupIdentifier:
          type: string
          description: Controller-assigned setup identifier
        webWidth:
          type: integer
          description: Web width in Ten Micron
        edgeTrimming:
          type: integer
          description: Edge trimming (setup_trim / 2) in Ten Micron
        boardGrade:
          type: string
          description: Board grade name
        fluteType:
          type: string
          nullable: true
          description: Flute type (BHS 4.2.5 only)
        whiteTop:
          type: boolean
          nullable: true
          description: White top flag (BHS 4.2.5 only)
        waterproofStarch:
          type: boolean
          nullable: true
          description: Waterproof starch flag (BHS 4.2.5 only)
        scheduledLineal:
          type: integer
          format: int64
          description: Scheduled lineal in millimetres
        boardThickness:
          type: integer
          description: Board thickness in microns
        speedOnOrderChange:
          type: integer
          description: Machine speed on order change in mm/min
        speedAfterOrderChange:
          type: integer
          description: Machine speed after order change in mm/min
        knives:
          type: array
          items:
            $ref: '#/components/schemas/KnifeSetup'

    KnifeSetup:
      type: object
      properties:
        knifeNumber:
          type: integer
        orderNumber:
          type: string
        customerName:
          type: string
        nextMachine:
          type: string
        destinationLine:
          type: integer
          description: Always 0 in BHS 4.2.5
        estimatedCuts:
          type: integer
        numberOfOuts:
          type: integer
        sheetLength:
          type: integer
          description: Sheet length in Ten Micron
        stackHeight:
          type: integer
          description: Stack height in sheets
        scores:
          type: array
          items:
            type: integer
          description: Relative score positions in Ten Micron
        scoreTypeIndexes:
          type: array
          nullable: true
          items:
            type: integer
          description: Score type indexes (BHS 4.2.5 only)

    CorrugatorSetupUpdate:
      type: object
      description: Partial update request. Only non-null fields are applied.
      properties:
        speedOnOrderChange:
          type: integer
          nullable: true
          description: New speed on order change in mm/min
        speedAfterOrderChange:
          type: integer
          nullable: true
          description: New speed after order change in mm/min
        prewarnDistance:
          type: integer
          nullable: true
          description: Prewarn distance in Ten Micron
        whiteTop:
          type: boolean
          nullable: true
        waterproofStarch:
          type: boolean
          nullable: true

    ErrorData:
      type: object
      properties:
        error:
          $ref: '#/components/schemas/ErrorDetail'
        details:
          type: array
          items:
            $ref: '#/components/schemas/ErrorDetail'

    ErrorDetail:
      type: object
      properties:
        code:
          type: string
        logMessage:
          type: string
        parameters:
          type: object

  responses:
    UnauthorizedError:
      description: Unauthorized — OAuth2 scope missing or token invalid.
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorData'
    BadRequestError:
      description: Bad request.
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorData'
    InternalServerError:
      description: Internal server error.
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorData'
```

#### Notes

- Keep the `securitySchemes` section identical in structure to `corrugator_order_api.yaml` — only the scope names change.
- The `corrugator_setup_api.yaml` is a documentation artifact only; the actual security enforcement is done by `CscAuthenticationPatternConfigurator` and the OAuth2 `@SecurityRequirement` annotations.

---

### Task 9 — Add `TestCorrugatorSetupMapper`

**File:** `csc/kp-csc/kp-csc-service/testsrc/com/kiwiplan/csc/rest/service/TestCorrugatorSetupMapper.java`
**Change type:** Add

#### What to change

Unit tests for `CorrugatorSetupMapper.toDTO()` and `toKnifeDTO()`. Use JUnit 5 (`@Test`, `@DisplayName`). Use Mockito to provide domain model doubles.

#### Why

The mapper must be independently verified before the service and controller tests depend on it.

#### Code

```java
package com.kiwiplan.csc.rest.service;

import com.kiwiplan.csc.rest.dto.CorrugatorSetupDTO;
import com.kiwiplan.csc.rest.dto.KnifeSetupDTO;
import kiwiplan.csc.model.corrugators.Corrugator;
import kiwiplan.csc.model.setups.SetupKnife;
import kiwiplan.csc.model.setups.SetupRun;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Collections;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@DisplayName("CorrugatorSetupMapper Tests")
class TestCorrugatorSetupMapper {

    private CorrugatorSetupMapper mapper;

    @BeforeEach
    void setUp() {
        mapper = new CorrugatorSetupMapper();
    }

    @Test
    @DisplayName("Given populated SetupRun and Corrugator, When toDTO called, Then all fields are mapped")
    void testToDTO_populatedSetup() {
        Corrugator corrugator = mock(Corrugator.class);
        when(corrugator.getName()).thenReturn("CORR-1");

        SetupRun setupRun = mock(SetupRun.class);
        when(setupRun.getSetupNumber()).thenReturn(574);
        when(setupRun.getControllerId()).thenReturn("CTRL-574");
        when(setupRun.getWebWidth()).thenReturn(12500);
        when(setupRun.getSetupTrim()).thenReturn(400);
        when(setupRun.getBoardName()).thenReturn("GRADE-A");
        when(setupRun.getFluteTypeName()).thenReturn("BC");
        when(setupRun.getWhiteTop()).thenReturn(Boolean.FALSE);
        when(setupRun.getWaterproofStarch()).thenReturn(Boolean.TRUE);
        when(setupRun.getEstimatedLineal()).thenReturn(50000L);
        when(setupRun.getBoardThickness()).thenReturn(4000);
        when(setupRun.getRunSpeedOnOrderChange()).thenReturn(200000);
        when(setupRun.getRunSpeedAfterOrderChange()).thenReturn(180000);
        when(setupRun.getKnives()).thenReturn(Collections.emptyList());

        CorrugatorSetupDTO dto = mapper.toDTO(setupRun, corrugator);

        assertEquals(574, dto.getSetupNumber());
        assertEquals("CORR-1", dto.getCorrugatorName());
        assertEquals("CTRL-574", dto.getSetupIdentifier());
        assertEquals(12500, dto.getWebWidth());
        assertEquals(200, dto.getEdgeTrimming()); // 400 / 2
        assertEquals("GRADE-A", dto.getBoardGrade());
        assertEquals("BC", dto.getFluteType());
        assertFalse(dto.getWhiteTop());
        assertTrue(dto.getWaterproofStarch());
        assertEquals(50000L, dto.getScheduledLineal());
        assertEquals(4000, dto.getBoardThickness());
        assertEquals(200000, dto.getSpeedOnOrderChange());
        assertEquals(180000, dto.getSpeedAfterOrderChange());
        assertNotNull(dto.getKnives());
        assertTrue(dto.getKnives().isEmpty());
    }

    @Test
    @DisplayName("Given null optional fields, When toDTO called, Then nullable fields are null in DTO")
    void testToDTO_nullOptionalFields() {
        Corrugator corrugator = mock(Corrugator.class);
        when(corrugator.getName()).thenReturn("CORR-1");

        SetupRun setupRun = mock(SetupRun.class);
        when(setupRun.getSetupNumber()).thenReturn(574);
        when(setupRun.getControllerId()).thenReturn(null);
        when(setupRun.getWebWidth()).thenReturn(null);
        when(setupRun.getSetupTrim()).thenReturn(null);
        when(setupRun.getBoardName()).thenReturn(null);
        when(setupRun.getFluteTypeName()).thenReturn(null);
        when(setupRun.getWhiteTop()).thenReturn(null);
        when(setupRun.getWaterproofStarch()).thenReturn(null);
        when(setupRun.getEstimatedLineal()).thenReturn(null);
        when(setupRun.getBoardThickness()).thenReturn(null);
        when(setupRun.getRunSpeedOnOrderChange()).thenReturn(null);
        when(setupRun.getRunSpeedAfterOrderChange()).thenReturn(null);
        when(setupRun.getKnives()).thenReturn(null);

        CorrugatorSetupDTO dto = mapper.toDTO(setupRun, corrugator);

        assertNull(dto.getSetupIdentifier());
        assertNull(dto.getWebWidth());
        assertNull(dto.getEdgeTrimming());
        assertNull(dto.getBoardGrade());
        assertNull(dto.getFluteType());
        assertNull(dto.getWhiteTop());
        assertNull(dto.getWaterproofStarch());
        assertNull(dto.getScheduledLineal());
        assertNull(dto.getBoardThickness());
        assertNull(dto.getSpeedOnOrderChange());
        assertNull(dto.getSpeedAfterOrderChange());
        assertNotNull(dto.getKnives());
        assertTrue(dto.getKnives().isEmpty());
    }
}
```

#### Notes

- Getter names (`getWebWidth()`, `getSetupTrim()`, etc.) on `SetupRun` are **NOT** simple field getters — `SetupRun` uses a rich domain model. The confirmed approach navigates: `setupRun.getWetendRun().getWetendConfiguration().getRollWidth()` for web width, `setupRun.getBoard()` for material/board, `setupRun.getSetupKnives()` for knives. Adjust mock expectations to use the correct object graph once `SetupConfiguration.java` is confirmed.
- Board-level fields (thickness, speeds, white top, starch) are expected to be on `SetupConfiguration` — read the class before writing final mapper code.

---

### Task 10 — Add `TestCorrugatorSetupService`

**File:** `csc/kp-csc/kp-csc-service/testsrc/com/kiwiplan/csc/rest/service/TestCorrugatorSetupService.java`
**Change type:** Add

#### What to change

Unit tests covering:
1. `getActiveCorrugatorByName` — success, not found, all retired.
2. `fetchSetupDetails` — success, setup not found.
3. `updateSetup` — success partial update, setup not found.

Follow the structure of `TestCorrugatorSetupLineupService`.

#### Code

```java
package com.kiwiplan.csc.rest.service;

import com.kiwiplan.csc.rest.dto.CorrugatorSetupDTO;
import com.kiwiplan.csc.rest.dto.CorrugatorSetupUpdateDTO;
import com.kiwiplan.csc.rest.exception.CorrugatorNotFoundException;
import com.kiwiplan.csc.rest.exception.CorrugatorSetupNotFoundException;
import kiwiplan.csc.model.corrugators.Corrugator;
import kiwiplan.csc.model.setups.SetupRun;
import kiwiplan.csc.model.setups.SetupStatus;
import kiwiplan.csc.service.CscService;
import kiwiplan.csc.service.CscServiceException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@DisplayName("CorrugatorSetupService Tests")
class TestCorrugatorSetupService {

    private static final String CORRUGATOR_NAME = "CORR-1";
    private static final Integer SETUP_NUMBER = 574;
    private static final Long CORRUGATOR_ID = 100L;

    @Mock
    private CscService cscService;

    @Mock
    private CorrugatorSetupMapper mapper;

    @InjectMocks
    private CorrugatorSetupService service;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
    }

    // --- getActiveCorrugatorByName ---

    @Test
    @DisplayName("Given valid corrugator name, When getActiveCorrugatorByName, Then return corrugator")
    void testGetActiveCorrugatorByName_success() throws CscServiceException {
        Corrugator corrugator = mock(Corrugator.class);
        when(corrugator.isRetired()).thenReturn(false);
        when(cscService.getCorrugatorsByName(CORRUGATOR_NAME)).thenReturn(Collections.singletonList(corrugator));

        Corrugator result = service.getActiveCorrugatorByName(CORRUGATOR_NAME);

        assertNotNull(result);
        assertSame(corrugator, result);
    }

    @Test
    @DisplayName("Given unknown corrugator name, When getActiveCorrugatorByName, Then throw CorrugatorNotFoundException")
    void testGetActiveCorrugatorByName_notFound() throws CscServiceException {
        when(cscService.getCorrugatorsByName(CORRUGATOR_NAME)).thenReturn(Collections.emptyList());

        assertThrows(CorrugatorNotFoundException.class,
                () -> service.getActiveCorrugatorByName(CORRUGATOR_NAME));
    }

    @Test
    @DisplayName("Given all corrugators retired, When getActiveCorrugatorByName, Then throw CorrugatorNotFoundException")
    void testGetActiveCorrugatorByName_allRetired() throws CscServiceException {
        Corrugator retired = mock(Corrugator.class);
        when(retired.isRetired()).thenReturn(true);
        when(cscService.getCorrugatorsByName(CORRUGATOR_NAME)).thenReturn(Collections.singletonList(retired));

        assertThrows(CorrugatorNotFoundException.class,
                () -> service.getActiveCorrugatorByName(CORRUGATOR_NAME));
    }

    // --- fetchSetupDetails ---

    @Test
    @DisplayName("Given valid corrugator and setup number, When fetchSetupDetails, Then return populated DTO")
    void testFetchSetupDetails_success() throws Exception {
        Corrugator corrugator = mock(Corrugator.class);
        when(corrugator.getId()).thenReturn(CORRUGATOR_ID);
        when(corrugator.getName()).thenReturn(CORRUGATOR_NAME);

        SetupRun setupRun = mock(SetupRun.class);
        when(cscService.getSetupRunBySetupNumber(eq(CORRUGATOR_ID), eq(SETUP_NUMBER), anyList()))
                .thenReturn(setupRun);

        CorrugatorSetupDTO expectedDTO = new CorrugatorSetupDTO();
        when(mapper.toDTO(setupRun, corrugator)).thenReturn(expectedDTO);

        CorrugatorSetupDTO result = service.fetchSetupDetails(corrugator, SETUP_NUMBER);

        assertSame(expectedDTO, result);
    }

    @Test
    @DisplayName("Given setup not found, When fetchSetupDetails, Then throw CorrugatorSetupNotFoundException")
    void testFetchSetupDetails_setupNotFound() throws Exception {
        Corrugator corrugator = mock(Corrugator.class);
        when(corrugator.getId()).thenReturn(CORRUGATOR_ID);
        when(corrugator.getName()).thenReturn(CORRUGATOR_NAME);

        when(cscService.getSetupRunBySetupNumber(eq(CORRUGATOR_ID), eq(SETUP_NUMBER), anyList()))
                .thenReturn(null);

        assertThrows(CorrugatorSetupNotFoundException.class,
                () -> service.fetchSetupDetails(corrugator, SETUP_NUMBER));
    }

    // --- updateSetup ---

    @Test
    @DisplayName("Given valid update DTO, When updateSetup, Then apply changes and return updated DTO")
    void testUpdateSetup_success() throws Exception {
        Corrugator corrugator = mock(Corrugator.class);
        when(corrugator.getId()).thenReturn(CORRUGATOR_ID);
        when(corrugator.getName()).thenReturn(CORRUGATOR_NAME);

        SetupRun setupRun = mock(SetupRun.class);
        when(cscService.getSetupRunBySetupNumber(eq(CORRUGATOR_ID), eq(SETUP_NUMBER), anyList()))
                .thenReturn(setupRun);

        CorrugatorSetupUpdateDTO updateDTO = new CorrugatorSetupUpdateDTO();
        updateDTO.setSpeedOnOrderChange(210000);

        CorrugatorSetupDTO expectedDTO = new CorrugatorSetupDTO();
        when(mapper.toDTO(setupRun, corrugator)).thenReturn(expectedDTO);

        CorrugatorSetupDTO result = service.updateSetup(corrugator, SETUP_NUMBER, updateDTO);

        verify(setupRun).setRunSpeedOnOrderChange(210000);
        verify(cscService).storeSetupRun(setupRun);
        assertSame(expectedDTO, result);
    }
}
```

#### Notes

- Getter and setter names on `SetupRun` (`setRunSpeedOnOrderChange`, etc.) must be verified against the model before running tests. Adjust accordingly.
- The `storeSetupRun` method on `CscService` must be confirmed (see Task 5 note). If the method name differs, update the `verify(cscService).storeSetupRun(...)` assertion.

---

### Task 11 (bonus — can be done in parallel with Task 10) — Add `TestCorrugatorSetupController`

**File:** `csc/kp-csc/kp-csc-service/testsrc/com/kiwiplan/csc/rest/controller/v1/TestCorrugatorSetupController.java`
**Change type:** Add

#### What to change

Unit tests for `CorrugatorSetupController`:
1. GET — success (HTTP 200, DTO returned).
2. GET — corrugator not found (exception propagates).
3. PATCH — success (HTTP 200, updated DTO returned).
4. PATCH — setup not found (exception propagates).

Follow `TestCorrugatorSetupLineupController` style.

#### Code

```java
package com.kiwiplan.csc.rest.controller.v1;

import com.kiwiplan.csc.rest.dto.CorrugatorSetupDTO;
import com.kiwiplan.csc.rest.dto.CorrugatorSetupUpdateDTO;
import com.kiwiplan.csc.rest.exception.CorrugatorNotFoundException;
import com.kiwiplan.csc.rest.exception.CorrugatorSetupNotFoundException;
import com.kiwiplan.csc.rest.service.CorrugatorSetupService;
import kiwiplan.csc.model.corrugators.Corrugator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@DisplayName("CorrugatorSetupController Tests")
class TestCorrugatorSetupController {

    private static final String CORRUGATOR_NAME = "CORR-1";
    private static final Integer SETUP_NUMBER = 574;

    @Mock
    private CorrugatorSetupService setupService;

    @InjectMocks
    private CorrugatorSetupController controller;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
    }

    @Test
    @DisplayName("Given valid corrugator name and setup number, When GET called, Then return HTTP 200")
    void testGetSetupDetails_success() throws Exception {
        Corrugator corrugator = mock(Corrugator.class);
        CorrugatorSetupDTO dto = new CorrugatorSetupDTO();

        when(setupService.getActiveCorrugatorByName(CORRUGATOR_NAME)).thenReturn(corrugator);
        when(setupService.fetchSetupDetails(corrugator, SETUP_NUMBER)).thenReturn(dto);

        ResponseEntity<CorrugatorSetupDTO> response = controller.getSetupDetails(CORRUGATOR_NAME, SETUP_NUMBER);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertSame(dto, response.getBody());
    }

    @Test
    @DisplayName("Given unknown corrugator, When GET called, Then CorrugatorNotFoundException propagates")
    void testGetSetupDetails_corrugatorNotFound() throws Exception {
        when(setupService.getActiveCorrugatorByName(CORRUGATOR_NAME))
                .thenThrow(new CorrugatorNotFoundException("Not found"));

        assertThrows(CorrugatorNotFoundException.class,
                () -> controller.getSetupDetails(CORRUGATOR_NAME, SETUP_NUMBER));
    }

    @Test
    @DisplayName("Given valid PATCH request, When PATCH called, Then return HTTP 200")
    void testUpdateSetupDetails_success() throws Exception {
        Corrugator corrugator = mock(Corrugator.class);
        CorrugatorSetupUpdateDTO updateDTO = new CorrugatorSetupUpdateDTO();
        CorrugatorSetupDTO dto = new CorrugatorSetupDTO();

        when(setupService.getActiveCorrugatorByName(CORRUGATOR_NAME)).thenReturn(corrugator);
        when(setupService.updateSetup(corrugator, SETUP_NUMBER, updateDTO)).thenReturn(dto);

        ResponseEntity<CorrugatorSetupDTO> response = controller.updateSetupDetails(CORRUGATOR_NAME, SETUP_NUMBER, updateDTO);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertSame(dto, response.getBody());
    }

    @Test
    @DisplayName("Given setup not found, When PATCH called, Then CorrugatorSetupNotFoundException propagates")
    void testUpdateSetupDetails_setupNotFound() throws Exception {
        Corrugator corrugator = mock(Corrugator.class);
        CorrugatorSetupUpdateDTO updateDTO = new CorrugatorSetupUpdateDTO();

        when(setupService.getActiveCorrugatorByName(CORRUGATOR_NAME)).thenReturn(corrugator);
        when(setupService.updateSetup(corrugator, SETUP_NUMBER, updateDTO))
                .thenThrow(new CorrugatorSetupNotFoundException("Not found"));

        assertThrows(CorrugatorSetupNotFoundException.class,
                () -> controller.updateSetupDetails(CORRUGATOR_NAME, SETUP_NUMBER, updateDTO));
    }
}
```

---

## Backward Compatibility Assessment

| Changed interface | Type | Consumer impact |
|---|---|---|
| New `GET /api/v1/corrugators/{corrugatorName}/setups/{setupNumber}` | Additive | No existing consumer; new endpoint only. |
| New `PATCH /api/v1/corrugators/{corrugatorName}/setups/{setupNumber}` | Additive | No existing consumer; new endpoint only. |
| `CscAuthenticationPatternConfigurator` — new routes added | Additive | No existing routes removed or changed. Existing security rules unaffected. |
| New DTO classes | Additive | No existing DTOs changed. |
| New service / mapper / controller classes | Additive | No existing classes changed. |

**All changes are purely additive. No version bump is required.**

---

## Test Plan

| Test Class | Test Method | What it verifies |
|---|---|---|
| `TestCorrugatorSetupMapper` | `testToDTO_populatedSetup` | All BHS P02 fields are mapped correctly from SetupRun + Corrugator |
| `TestCorrugatorSetupMapper` | `testToDTO_nullOptionalFields` | Nullable fields return null (not false/empty) when absent from domain object |
| `TestCorrugatorSetupService` | `testGetActiveCorrugatorByName_success` | Active corrugator returned when name matches |
| `TestCorrugatorSetupService` | `testGetActiveCorrugatorByName_notFound` | `CorrugatorNotFoundException` thrown when name not found |
| `TestCorrugatorSetupService` | `testGetActiveCorrugatorByName_allRetired` | `CorrugatorNotFoundException` thrown when all matching corrugators are retired |
| `TestCorrugatorSetupService` | `testFetchSetupDetails_success` | DTO populated from SetupRun via mapper |
| `TestCorrugatorSetupService` | `testFetchSetupDetails_setupNotFound` | `CorrugatorSetupNotFoundException` when setup is null |
| `TestCorrugatorSetupService` | `testUpdateSetup_success` | Non-null fields applied to SetupRun; setup persisted; DTO returned |
| `TestCorrugatorSetupController` | `testGetSetupDetails_success` | HTTP 200 returned with DTO body |
| `TestCorrugatorSetupController` | `testGetSetupDetails_corrugatorNotFound` | `CorrugatorNotFoundException` propagates from controller |
| `TestCorrugatorSetupController` | `testUpdateSetupDetails_success` | HTTP 200 returned for valid PATCH |
| `TestCorrugatorSetupController` | `testUpdateSetupDetails_setupNotFound` | `CorrugatorSetupNotFoundException` propagates from controller |

---

## Dependencies and Risks

| Item | Type | Notes |
|---|---|---|
| `SetupRun` domain model fields | Dependency | **Partially confirmed.** `getSetupKnives()` (not `getKnives()`), `getBoard()` for `MaterialType`, `getTotalEstimatedLength()` for lineal, `getWetendRun().getWetendConfiguration().getRollWidth()` for web width. Board thickness, speed fields, controllerId, flute/starch/whiteTop — likely in `SetupConfiguration`; must be verified before implementing Task 4. |
| `CscService` persist method | Dependency | **Confirmed:** `storeSetupRunAndSetupConfiguration(SetupRun)` is the correct single-setup persist method. Also throws `SetupInProtectedRegionException` — must be handled in Task 5. |
| `CscService.getCorrugatorsByName()` returns a `List` | Risk | Names may not be unique across plants. Service filters retired and returns first active. If multiple active corrugators share the same name, the behaviour is first-match (log a warning). Confirm uniqueness constraint with domain team if this matters. |
| `SetupStatus` list for GET/PATCH | Risk | `ACTIVE_SETUP_STATUSES` in Task 5 is set to `[ISSUED, PROCESSING]`. If BHS needs to fetch setups in `FINISHED` or `RETURNED` state (e.g. recently completed), expand the list. Confirm with the domain team. |
| Writable fields in PATCH | Risk | `CorrugatorSetupUpdateDTO` writable fields are based on BHS template analysis. Must be verified against `vue-csc-business-logics-in-xml-contracts.md` before committing the field list. |
| `KnifeSetupDTO.scores` and `scoreTypeIndexes` data sources | Risk | The exact getter methods on `SetupKnife` for score positions and score type indexes must be confirmed from the model |
| `csc_api.yaml` / `csc_api.yaml` registration | Dependency | If the existing `csc_api.yaml` in `src/` is an aggregation file that includes individual YAML docs, confirm whether `corrugator_setup_api.yaml` must be referenced there or is standalone documentation only |

---

## Pre-Implementation Checklist

Before writing any code, complete these research steps (these are blockers):

1. **Read `SetupRun.java` and `SetupConfiguration.java`** — these are the primary sources.
   - Web width: confirmed navigation is `setupRun.getWetendRun().getWetendConfiguration().getRollWidth()` (returns `Lineal`).
   - Knives: confirmed as `setupRun.getSetupKnives()` (returns `List<SetupKnife>`).
   - Scheduled lineal: confirmed as `setupRun.getTotalEstimatedLength()` (returns `Lineal`).
   - Board: confirmed as `setupRun.getBoard()` (returns `MaterialType`).
   - **Still need to confirm:** `controllerId`, `boardThickness`, `fluteTypeName`, `whiteTop`, `waterproofStarch`, run speeds — these are likely in `SetupConfiguration`. Run:
     ```bash
     grep -n "public.*get\|public.*set" \
       /home/laksyalamat/projects/KP-MapJava/csc/kp-csc/kp-csc-api/src/kiwiplan/csc/model/setups/SetupConfiguration.java
     ```

2. **`SetupKnife.java` — confirmed accessors (from source analysis):**
   - `getNumberOut()` → `int` (number of outs) ✓
   - `getOrderedBoardLength()` → `Lineal` (sheet length) ✓
   - `getSheetsPerStack()` → `Integer` (stack height) ✓
   - `getScoreSet()` → `ScoreSet` (score data, via `getSetupOrder().getCorrugatorOrder().getActualScores()`) ✓
   - `getSetupOrder().getCorrugatorOrder()` → `CorrugatorOrder` ✓
   - `getKnife()` → `CorrugatorKnife` (need to confirm `getKnifeNumber()` on `CorrugatorKnife`)
   - **Still need to confirm:** `estimatedCuts` getter — not found in source scan. Run:
     ```bash
     grep -n "EstimatedCuts\|estimatedCuts\|getEstimated" \
       /home/laksyalamat/projects/KP-MapJava/csc/kp-csc/kp-csc-api/src/kiwiplan/csc/model/setups/SetupKnife.java
     ```
   - **`ScoreSet` accessor for positions:** Run:
     ```bash
     grep -n "public.*get" \
       /home/laksyalamat/projects/KP-MapJava/csc/kp-csc/kp-csc-api/src/kiwiplan/manufacturing/model/scores/ScoreSet.java
     ```

3. **`CscService` persist method — confirmed:**
   - `storeSetupRunAndSetupConfiguration(SetupRun)` is available. It throws `CscServiceException` AND `SetupInProtectedRegionException`.
   - Import: `kiwiplan.csc.service.exception.SetupInProtectedRegionException`
   - Wrap `SetupInProtectedRegionException` as `CscServiceException` in the service layer.
   - Alternatively: `storeSetupRuns(List<SetupRun>)` is void and simpler but bulk-only.

4. **Read KnowledgeBase docs** (fetch via ADO MCP if not already local):
   - `feature-design-corrugator-link.md` — confirm API shape
   - `vue-csc-business-logics-in-xml-contracts.md` — confirm writable PATCH fields

---

## Out of Scope

| Item | Reason |
|---|---|
| Link Central integration (calling the new CSC endpoint from Link Central) | This work item creates the CSC service endpoint only. Integration from Link Central is a separate work item. |
| Frontend / React changes | No UI work is in scope. |
| Classic XMGEN Groovy template changes | The BHS templates in `KP-MapJava/comms/` are reference documentation; they do not need to be changed. |
| Existing endpoint changes (`CorrugatorSetupLineupController`, `CorrugatorOrderController`) | No modifications to existing controllers. |
| Database migration scripts | The new endpoints read/write from existing `XDATA`/`SetupRun` tables; no schema changes are required. |
