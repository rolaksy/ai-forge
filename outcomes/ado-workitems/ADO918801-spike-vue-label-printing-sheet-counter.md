# Spike Work Item: VUE Label Printing for Kiwiplan Sheet Counter Protocol

**Generated from:** ADO 918801 TDD review + codebase analysis  
**Date:** 2025-07-04  
**Parent Work Item:** ADO 918801 — `@Brian TDD | Sheet Counter | 1.0 | VUE | TBD (25.4?)`  
**Customer:** Irani Papel E Embalagem SA (Vargem Bonita, Santa Catarina, Brazil)  
**Go-live target:** 2026-09-01 | **Release target:** 25.4  

---

## Spike Work Item

### Title

`Spike: Investigate VUE Label Printing Support for Kiwiplan Sheet Counter Protocol (kiwi_sheetcounter_1.0) — Irani Papel`

---

### Work Item Type

`User Story` (Spike)

---

### Description

#### Background

Irani Papel E Embalagem SA is migrating from Classic XMIT to **CSC VUE + PCS VUE** (go-live September 2026, target release 25.4). They use a **Kiwiplan standard sheet counter** link (`kiwi_sheetcounter_1.0`, XMIT port: `eagle:7764`, protocol: `socgen`), which sends barcode scan (UPD) and sheet count (CNT) messages to XMGEN over TCP/IP.

Their XMIT configuration has **INV/AU Autoprint = Y**, meaning after each unit count (CNT message), XMGEN should automatically print a label for that unit. Existing system tests 316276 and 319958 validate unitque autoprint as core behaviour.

The TDD (PR #39158, ADO 918801) confirmed the base sheet counter protocol works in PCS VUE. During PO review, the customer confirmed they **want VUE label printing** for counted units when migrating to VUE — not the Classic label path.

#### Current State (Classic Path)

When a CNT message is processed in XMGEN, the call chain is:

```
xmg_unitque_upd()                           [gen/xmgact5.f ~line 958]
  └─ xmg_unitque_autoprint_label(label_type)  [gen/xmgact5.f ~line 3052]
       └─ procoff 'lab00' <args>              ← Classic label printer ONLY
```

`xmg_unitque_autoprint_label()` currently uses only the Classic `lab00` process. It has **no VUE/PCS label path**.

#### Existing VUE Label Infrastructure (WIP/Converting Path)

A VUE label printing mechanism already exists for the WIP/PCS converting machine flow:

| Component | Location | Role |
|---|---|---|
| `pcs_label_xml()` | `KP-MAP/lib/pcslabelxml.f` | Generates XML request with `action="PCSLABEL"`, sends to KP-MapJava comms layer |
| `xmg_print_wip_label()` | `KP-MAP/gen/xmgact5.f ~line 4497` | Calls `pcs_label_xml()` when verb `PCS_LABEL_DATA` is defined |
| `LabellingPCSLabelHandler` | `KP-MapJava: comms/kp-comms/kp-comms-impl/.../labelling/` | Handles `PCSLABEL` action; uses `LineupEntry` + `FeedbackId` data model |
| `PcsLabelController` | `KP-MapJava: lbs/label-print-service/.../rest/controller/` | REST `POST v1/pcs-labels` → `pcsService.printLabels()` |
| `LabellingCommsHandlerFactory` | `KP-MapJava: comms/kp-comms/kp-comms-impl/.../labelling/` | Registers `"PCSLABEL"` action handler |

The comment in `pcslabelxml.f` explicitly states: _"currently this subroutine supports WIP label printing only"_.

#### Key Technical Gap

The **WIP/PCS VUE label flow** uses the `LineupEntry + FeedbackId` data model (from `WORKIP`/`FACTRY` records with job/series/step identifiers). The **sheet counter label flow** uses the `ULOADC`/`UNITQUE` data model (barcode, unit number, quantity, label format code from INV/AU config). These are architecturally different:

- `LabellingPCSLabelHandler` currently calls `pcsService.getLineupEntry(orderNumber, jobNumber, stepNumber)` and `pcsService.getLatestFeedbackIdForLineupEntry(lineupId)`.
- Sheet counter data has no lineup entry / feedback — it has a unit barcode and a raw count.
- `xmg_unitque_autoprint_label()` has access to: unit barcode, unit number, order number, quantity per unit, label type (from INV/AU `Label Format`). It does **not** have a lineup entry or PCS feedback.

Precedent: Feature 666481 (Opsigal sheet counter PCSLABEL) used the same `xmg_unitque_autoprint_label()` function. Branch `feature/pcslabel-vue` in KP-MAP may contain partial work — this needs to be assessed.

#### Spike Goal

Investigate and document what development changes are required to support VUE label printing when the Kiwiplan sheet counter counts a unit (CNT message processed, INV/AU Autoprint = Y). Produce a concrete implementation plan with estimated effort.

---

### Acceptance Criteria

> **Definition of Done for this Spike:** A detailed implementation plan document is produced, reviewed by the developer, and accepted by the PO/tech lead. The plan must be specific enough that a developer can implement it with no further research.

---

#### AC-1: Data Model Analysis

- [ ] Document what data is available in `xmg_unitque_autoprint_label()` at the time of calling (unit barcode, order number, unit number, quantity, label type from INV/AU).
- [ ] Document what data `LabellingPCSLabelHandler` / `pcsService.printLabels()` currently requires (lineup entry ID, feedback ID, quantity per unit, quantity per bundle, label type, copies).
- [ ] Identify the gap: what fields are missing/different between ULOADC/UNITQUE and the lineup+feedback model.
- [ ] Determine whether `PcsService.printLabels()` can accept a UNITQUE-based label request OR whether a separate service method/endpoint is needed.

#### AC-2: Assess `feature/pcslabel-vue` Branch in KP-MAP

- [ ] Review the `feature/pcslabel-vue` branch (and related branches: `feature/pcslabel`, `feature/pcslabel-24.3`, `feature/pcslabel-24.4`) in KP-MAP.
- [ ] Determine if any branch contains a VUE label path inside `xmg_unitque_autoprint_label()`.
- [ ] Confirm whether the Opsigal sheet counter (Feature 666481) implemented a unitque→PCSLABEL path and, if so, whether it is reusable for Kiwiplan (non-Opsigal) sheet counter.
- [ ] Document the merge/reuse status of those branches.

#### AC-3: KP-MAP (FORTRAN) Changes Required

- [ ] Define the changes needed in `xmg_unitque_autoprint_label()` in `gen/xmgact5.f` to detect VUE mode and call the VUE label path (analogous to how `xmg_print_wip_label()` calls `pcs_label_xml()`).
- [ ] Determine whether `pcs_label_xml()` in `lib/pcslabelxml.f` can be reused or needs a new/extended subroutine (e.g., `pcs_unitque_label_xml()`) to pass UNITQUE-specific data.
- [ ] Define what XML payload structure XMGEN must send to KP-MapJava for a sheet counter label request (action, order number, unit number, barcode, quantity, label type, copies).
- [ ] Confirm the INV/AU configuration parameter(s) required to enable the VUE path (e.g., existing `Autoprint` flag or a new VUE-specific flag).

#### AC-4: KP-MapJava Changes Required

- [ ] Determine whether `LabellingPCSLabelHandler` needs to be extended to handle UNITQUE-based requests, or whether a new handler (e.g., `LabellingUnitqueHandler`) should be created and registered in `LabellingCommsHandlerFactory`.
- [ ] Define what `CommsLabelling` model fields need to be populated from the UNITQUE XML payload (or whether a new comms model is needed).
- [ ] Identify what PCS service method(s) are needed to print a label given UNITQUE data (no lineup/feedback context). Determine whether this requires: (a) a new `printLabels` overload in `PcsService`, (b) a new service method, or (c) a direct call to the label-print REST endpoint with different parameters.
- [ ] Confirm exception handling: what error codes should be returned if the unit has no valid label template or barcode is not found.

#### AC-5: Label Template Considerations

- [ ] Identify what INV/AU label format codes are configured at Irani Papel and whether matching VUE label templates exist in the label print service.
- [ ] Determine what data fields the VUE label template requires for a sheet counter unit label (vs. a WIP/PCS label).
- [ ] Confirm with the label/PCS team whether a new VUE label template type is needed for UNITQUE labels, or whether an existing template can be reused/parameterised.

#### AC-6: Test Strategy

- [ ] Define how to test end-to-end VUE label printing for the sheet counter in a QA/test environment (what hardware simulator or mock is needed for the `kiwi_sheetcounter_1.0` protocol, or can existing test infrastructure be used).
- [ ] Identify existing system tests (316276, 319958) that validate unitque autoprint in Classic — determine what VUE equivalents are needed.
- [ ] Confirm whether Irani Papel's XMIT config (defines `USE_UNIT_BUNDLES_PER_PALLET`, `ULTUPDATE`) has any impact on the VUE label path.

#### AC-7: Effort Estimate

- [ ] Produce a breakdown of estimated development effort (in days or story points) for:
  - KP-MAP FORTRAN changes
  - KP-MapJava handler/service changes
  - Label template work (if needed)
  - Integration testing
- [ ] Confirm feasibility of delivery within release 25.4 given go-live date of 2026-09-01 and dev ready date of 2026-07-02.

---

### Notes for Spike Investigator

- Reference implementation: Feature 666481 (Opsigal sheet counter PCSLABEL / VUE label).
- The gap is **not** in the comms protocol layer (the UDP/CNT messages already work in VUE). The gap is purely in the **label-printing action** triggered after a successful count.
- The Classic autoprint path (`procoff lab00`) will continue to work during the migration period; VUE label path is an additive enhancement, not a replacement.
- `pcslabelxml.f` comment: _"currently this subroutine supports WIP label printing only"_ — this is the key file to extend or parallel.
- Irani Papel site defines: `USE_UNIT_BUNDLES_PER_PALLET`, `ULTUPDATE`, `INV/AU Autoprint = Y`, port `eagle:7764`, protocol `socgen`, timeout `10s`.
