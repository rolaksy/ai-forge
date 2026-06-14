# ADO 918801 — TDD Review: Kiwiplan Sheet Counter 1.0 | VUE

**ADO Work Item:** [918801](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/918801)  
**TDD PR:** [#39158](https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-KnowledgeBase/pullrequest/39158)  
**Customer:** Irani Papel e Embalagem S/A (Porto Alegre, Brazil)  
**Target Release:** 25.4  
**Reviewed by:** Laks Yalamati  
**Review Date:** 2026-05-15

---

## Part 1 — What Is a Sheet Counter? (Background Reading)

If you haven't worked with a sheet counter before, this section explains what it is, where it sits in a corrugator plant, and how Kiwiplan talks to it.

### 1.1 Physical Context — What Does a Sheet Counter Do?

In a corrugated cardboard manufacturing plant, the corrugator produces large sheets of cardboard that are stacked into units (also called loads or pallets). After stacking, each unit needs to be counted accurately before it is labelled and shipped.

A **Sheet Counter** is a standalone machine placed on the conveyor line between the stacker and the shipping area. It works like this:

1. A forklift operator assembles the unit and places a **load label** (a barcode label) on it.
2. The conveyor moves the unit past the Sheet Counter station.
3. A **fixed barcode scanner** on the Sheet Counter reads the load label barcode.
4. A **camera** on the Sheet Counter takes a photograph of the edge of the unit and counts the number of individual sheets by looking at the flute profile (the wavy corrugated layer inside the cardboard).
5. The Sheet Counter sends the barcode and the count to Kiwiplan over a TCP/IP network connection.
6. Kiwiplan receives the count, looks up the order, and updates the unit quantity record.
7. If the quantity is within an acceptable range, Kiwiplan automatically prints a load label and accepts the unit.

In summary: **the Sheet Counter automates what would otherwise be a manual counting task at the end of the corrugator line.**

### 1.2 Where Is It in the Plant?

```
Corrugator Machine
        |
        v
   [Stacker/Unloader]
        |
        v  (forklift places load label on unit)
   [Conveyor Belt]
        |
        v
   [Sheet Counter Station] ← barcode scanner + camera
        |
        v  (TCP/IP message to Kiwiplan server)
   [XMGEN / Kiwiplan Server]
        |
        v
   UNITQUE1.DA file updated
   Bander Operator Screen updated (ULT)
   Load label printed (if INV/AU Autoprint = Y)
        |
        v
   [Shipping / Warehouse]
```

### 1.3 The Two Messages: UPD and CNT

The Kiwiplan Sheet Counter protocol (`kiwi_sheetcounter_1.0`) uses exactly **two request messages** and **two reply messages**:

| Message | Direction | Purpose |
|---------|-----------|---------|
| `UPD` (Update) | Sheet Counter → Kiwiplan | "I just scanned a barcode. Tell me the order details." |
| `upd` (reply) | Kiwiplan → Sheet Counter | Returns: customer name, order number, unit load number, number of units, flute type |
| `CNT` (Count) | Sheet Counter → Kiwiplan | "Here is the barcode and the sheet count I measured." |
| `cnt` (reply) | Kiwiplan → Sheet Counter | Acknowledgement. No payload beyond the command. |

**UPD flow (scan event):**
```
Sheet Counter scans barcode
    → sends: UPD + barcode (20 chars)
    → Kiwiplan looks up order via xmg_load_unit_details()
    → replies: upd + customer + order + unit# + numUnits + flute
    → Sheet Counter displays order details on its screen
```

**CNT flow (count event):**
```
Sheet Counter camera counts sheets
    → sends: CNT + barcode (20 chars) + sheetCount (5 chars)
    → Kiwiplan updates UNITQUE1.DA file (xmg_unitque_upd)
    → Kiwiplan triggers autoprint if INV/AU Autoprint = Y
    → replies: cnt (empty ack)
```

### 1.4 Protocol Technical Details

- **Transport:** TCP/IP socket over LAN
- **Connection model:** Sheet Counter is the **client** (initiates connection); XMGEN runs as the **server** (listens on port, e.g. `eagle:7764`)
- **Framing:** Each message is wrapped with `STX` (byte `0x02`) at the start and `ETX` (byte `0x03`) at the end
- **Field format:** All fields are fixed-width ASCII. Alphanumeric = left-justified with trailing spaces. Numeric = right-justified with leading spaces.
- **Transaction model:** The Sheet Counter sends one request and **waits for the reply before sending anything else.** It is fully synchronous.
- **Timeout & Retry:** If Kiwiplan does not reply within **10 seconds**, the Sheet Counter re-sends the last request. This means XMGEN might receive the same message twice — Kiwiplan handles this with the PRINTED/ACCEPTED status gate (see Section 2.3).

### 1.5 XMIT/XMGEN Configuration — How It Is Set Up in Kiwiplan

Kiwiplan's machine link layer is called **XMGEN** (Transmit Generator). It is configured through a series of database records under XMIT group keys:

| Record | Key | What It Does |
|--------|-----|-------------|
| `XMIT/PO` | `SHTCNT` | Port configuration: host/port (`eagle:7764`), protocol (`socgen`), timeout (`10` seconds) |
| `XMIT/XG` | `PARAMS` | Points to the message script file: `cntmess.scp` |
| `XMIT/XD` | `PARAMS` | Define words: `USE_UNIT_BUNDLES_PER_PALLET`, `ULTUPDATE` |

The `SOCGEN` (Socket Generic) protocol is Kiwiplan's generic TCP framing layer. By setting `SOCGEN_MODE server`, XMGEN listens for the Sheet Counter to connect.

### 1.6 SCP Files — The Script Layer

XMGEN uses script files (`.scp`) to define message formats and actions. For the sheet counter:

| File | Purpose |
|------|---------|
| `cntmess.scp` | Master message router — maps incoming function codes to scripts and actions |
| `cntupda.scp` | Defines the `UPD` request message structure (barcode field, id:935) |
| `cntupdr.scp` | Defines the `upd` reply message structure (customer, order, unit#, flute...) |
| `cntcnta.scp` | Defines the `CNT` request message structure (barcode + sheet count) |
| `cntcntr.scp` | Defines the `cnt` reply (empty acknowledgement) |
| `poll.scp` | Used by `CURR_RUN` — periodic polling for current run context |

The routing in `cntmess.scp`:
```
UPD received → run cntupda.scp → action: unitque_put → send back: REP_INFO (upd)
CNT received → run cntcnta.scp → action: unitque_upd → send back: REP_CNT_ACK (cnt)
```

### 1.7 What Happens Inside Kiwiplan When CNT Arrives

When XMGEN receives a `CNT` message, it calls `xmg_unitque_upd()` (in `gen/xmgact5.c`). Here is what that function does:

1. **Lock** the `UNITQUE1.DA` file (prevent concurrent writes).
2. **Read** the current unit record from `UNITQUE1.DA` using the barcode or current run order.
3. **Check** the current print status (`uq_print_statusZ`):
   - If already `P` (PRINTED) or `A` (ACCEPTED) → **do nothing** (prevents duplicate processing on timeout resend)
4. **Update** the quantity in the record with the count from `CNT.numberOfSheets`.
5. If `INV/AU Autoprint = Y` and count is in acceptable range → set status to `P` (PRINTED).
6. If count is within tolerance → set status to `A` (ACCEPTED).
7. **Unlock** the file.
8. **Update** `ULOADC` database record.
9. **Print label** via `xmg_unitque_autoprint_label()` if autoprint is on.

### 1.8 What Is UNITQUE1.DA?

`UNITQUE*.DA` is a flat file that acts as a queue of units waiting to be processed at the bander/counter station. The `n` in `UNITQUE1.DA` corresponds to the machine/counter number.

Each record holds:
- Barcode of the unit
- Order number
- Quantity (updated by the Sheet Counter)
- Print status (`P`=printed, `A`=accepted, blank=pending)
- Zone status

The **ULT Bander Operator screen** (`ult00 unitque=1`) reads this file and displays the list of pending units to the bander operator. When autoprint is on, the operator mostly just monitors — the counting and label printing happen automatically.

### 1.9 VUE Migration Context

This feature exists because the customer (Irani Papel) is migrating from **Classic** to **VUE** (PCS VUE + CSC VUE). The question being answered by this TDD is:

> **Does the sheet counter link still work when the site moves to VUE?**

The answer is **yes, with no code changes needed**, because:
- XMGEN runs as a Classic-side process — it continues to work the same way in a VUE deployment.
- The `UNITQUE*.DA` file, `ULOADC` database records, and Bander screen are all Classic-side — they are not replaced by VUE for this protocol.
- The only things that change in a VUE migration are scheduling/planning/production screens — not the machine link layer.

The concern that prompted this ticket was whether PCS VUE's scheduling and production reporting would correctly pick up the quantities counted by the sheet counter. The answer, confirmed by ADO 918387 (Fixed in 25.3), is that it does.

---

## Part 2 — TDD Review Findings

### 2.1 PR Structure Issues (Must Fix Before Merge)

| # | Issue | Severity | Action Required |
|---|-------|----------|----------------|
| 1 | `feature-920585.md` (BoxChek/ClearVision for Stora Enso) is in this PR — completely different feature | **High** | Move to its own separate PR |
| 2 | `kiwi_sheetcounter_1.0.pdf` added by mistake — confirmed by Brian in PR comments | **High** | Remove from this PR; keep in Feature ticket attachments |
| 3 | Both `feature-918801.md` and `feature-918801-tdd.md` appear in the PR for the same feature | **Medium** | Confirm which is the intended file; remove the duplicate |

### 2.2 Content Gaps

#### Gap 1 — No Test Plan (High)

The TDD says the work is "confined to validation/testing" but defines no test cases. For a validation-only feature, the test plan **is** the core deliverable.

Minimum test cases needed:

```
TC1: UPD happy path
  - Send UPD with a barcode that exists in ULOADC
  - Expect: upd reply contains correct customer name, order number, unit#, flute
  - Dataset: Irani Papel QA datadump

TC2: CNT happy path
  - Send CNT with valid barcode + sheetCount
  - Expect: UNITQUE1.DA updated with new quantity
  - Expect: cnt acknowledgement received

TC3: Timeout / resend behaviour
  - Simulate 10-second timeout (block reply)
  - Expect: Sheet Counter re-sends same message
  - Expect: XMGEN processes the resend correctly (no double-count)
  - Verify: PRINTED/ACCEPTED gate prevents duplicate update

TC4: CNT for already-PRINTED unit
  - Send CNT for a unit where print status = P
  - Expect: UNITQUE1.DA NOT modified (gate working)
  - Expect: cnt ack still returned

TC5: TCP socket retention
  - Send multiple UPD+CNT cycles on same TCP connection
  - Expect: connection stays open between transactions

TC6: UPD for unknown barcode
  - Send UPD with a barcode not in ULOADC
  - Document expected behaviour (timeout with control number 99999)
```

#### Gap 2 — INV/AU Autoprint During VUE Migration (High)

The work item resolution notes the site's `cntmess.scp` appears to have `INV/AU Autoprint = Y`. The code in `xmgact5.c:xmg_unitque_upd()` invokes `xmg_unitque_autoprint_label()` which calls Classic-side label printing. The TDD scopes out "label handling changes in VUE" but does not answer:

- Is label printing expected to continue working in Classic during the VUE migration period?
- What happens after full VUE cutover — does the label printing move to VUE (as was done in Feature 666481), or does it remain Classic-side?

Without this clarification, a QA engineer testing this feature does not know whether a missing autoprint is a bug or expected.

#### Gap 3 — ADO 918387 / 25.3 Fix Not Explicitly Linked to 25.4 (Medium)

ADO 918387 ("Sheet Counter | Kiwiplan | 1.0 | VUE | 25.3 | Opsigal") is referenced in the work item but not in the TDD. The TDD targets 25.4. It should explicitly state:

> _"The base implementation for sheet counter on VUE was delivered in 25.3 (ADO 918387). This feature targets 25.4 and includes that fix. No additional development is required."_

Without this, a reviewer can't tell if this TDD is describing new development or riding on existing work.

#### Gap 4 — `ULTUPDATE` Define Not Explained (Low)

`XMIT/XD` defines `ULTUPDATE`. This enables the `ultupdcheck` path in `xmg_ult_update()` which triggers real-time refresh of the ULT Bander Operator screen when a unit is processed. The TDD lists it without explanation. Even a one-line note ("enables real-time ULT bander screen refresh") would help.

#### Gap 5 — `poll.scp` / `CURR_RUN` Not Mentioned (Low)

`cntmess.scp` includes `|type:CURR_RUN|script:poll.scp|`. This drives periodic polling for current run machine context. Other VUE migration TDDs (e.g. ADO 748009, Fosber DryEnd) have flagged issues with `CURR_RUN` polling in VUE environments where object IDs differ. The TDD should note whether `poll.scp` was reviewed for VUE compatibility.

#### Gap 6 — Pending Validation Has No Owner or Date (Medium)

The TDD has this open item:
> _"Validation pending: confirm CNT.barcode resolves to the correct ULOADC record in the target deployment (customer data)."_

This is the **core correctness check** for the entire feature. It should have:
- An assigned owner
- A deadline (before 25.4 cut-off)
- A clear definition of done (e.g. "run TC1+TC2 against Irani Papel QA dataset and log results")

#### Gap 7 — Capitalization Inconsistencies (Low)

Jordan Newman already flagged this. Across the document:
- `Xmgen` / `XMGEN` / `xmgen` — use `XMGEN` throughout
- `PCS VUE` / `PCS/VUE` — use `PCS VUE` throughout

### 2.3 What Is Correct and Well-Done

- Protocol technical details match source code. STX/ETX framing, SOCGEN server mode, UPD/CNT message definitions, timeout/retry values — all verified against `cntmess.scp` and `cntupda/cntcnta.scp`.
- XMIT/PO, XMIT/XG, XMIT/XD configuration values correctly transcribed.
- PRINTED/ACCEPTED status gate noted — this is confirmed in `xmgact5.c:1255–1265`.
- Operator workflow (start/stop/reset) is clear and appropriate.
- Scope boundaries are clearly stated (no Bander screen dev, no VUE label dev, no MDC hardware).
- Work directory dump links provided (Irani Papel QA dataset).
- SCP file inventory is complete and correct.

---

## Part 3 — Questions to Raise in the PR

These are the questions you should post as comments on PR #39158:

### Q1 — On the duplicate files in the PR (Blocker)
> Can you confirm which file is the intended TDD for 918801: `feature-918801.md` or `feature-918801-tdd.md`? Both are in the PR and appear to have similar content. The other should be removed before merge.

### Q2 — On `feature-920585.md` being in the wrong PR (Blocker)
> `feature-920585.md` (BoxChek/ClearVision for Stora Enso) appears to have been included in this PR by mistake. Can this be moved to a separate PR so 918801 can be reviewed and merged independently?

### Q3 — On the test plan (Important)
> The TDD states the work is "confined to validation/testing" but I don't see defined test cases. What test cases are planned against the Irani Papel QA dataset? At minimum I would expect: (a) UPD scan → correct order details returned, (b) CNT count → UNITQUE updated correctly, (c) timeout/resend → no duplicate processing. Can you add a test plan section?

### Q4 — On label printing during migration (Important)
> The work item resolution notes the site has `INV/AU Autoprint = Y`. The TDD scopes out "label handling changes in VUE" but doesn't clarify: will Classic-side autoprint continue working during the VUE migration, or will label printing be a manual step post-migration? This matters for QA testing — should we verify autoprint is firing, or is it out of scope?

### Q5 — On ADO 918387 and the 25.3 fix (Important)
> The work item references ADO 918387 ("Fixed in 25.3") as an existing sheet counter VUE fix. This TDD targets 25.4. Can you confirm that 25.4 includes the 25.3 fix, and that this TDD is a validation-only exercise on top of that existing implementation? This context would help readers understand why no development is needed.

### Q6 — On the pending barcode resolution validation (Important)
> Section "Validation Status" says "Pending validation: confirm CNT.barcode resolves to the correct ULOADC record." Who is owning this validation step and what is the target date? This is the core correctness check — it should not be left as an open item without an owner.

### Q7 — On `poll.scp` / CURR_RUN VUE compatibility (Nice to have)
> `cntmess.scp` includes a `CURR_RUN → poll.scp` entry for periodic machine context polling. Has `poll.scp` been reviewed for VUE compatibility (object IDs etc.)? Other VUE migration TDDs in the KB have flagged CURR_RUN issues. If it's been confirmed OK, a one-liner noting that would close this off.

### Q8 — On `ULTUPDATE` define (Nice to have)
> `XMIT/XD` defines `ULTUPDATE` but the TDD doesn't explain what it does. Can you add a note? (It enables real-time refresh of the ULT Bander Operator screen when a unit record is updated.) Small thing but helps future readers.

---

## Part 4 — Reference Links

| Resource | Link |
|----------|------|
| ADO Work Item 918801 | https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/918801 |
| TDD PR #39158 | https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-KnowledgeBase/pullrequest/39158 |
| Related ADO 918387 (25.3 fix) | https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/918387 |
| Related ADO 604858 (9.8 fix) | https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/604858 |
| cntmess.scp (KP-MAP) | https://dev.azure.com/advantive-devops/Advantive/_git/KP-MAP?path=/scp/cntmess.scp |
| KP-MAP source repo | https://dev.azure.com/advantive-devops/Advantive/_git/KP-MAP |
| KP-Xmit-XmitTests repo | https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-XmitTests |
| Irani Papel QA Data | https://advantiveadmin.sharepoint.com/:u:/s/CustomerSupport/IQDxckxGTi3TTpoxW8ni4ezuAaV9muCu4D7q4f9fmFGyqFA |
| Irani Papel DataDump | https://advantiveadmin.sharepoint.com/:u:/s/CustomerSupport/IQBLlqHCGIQFTKsZnTx-ZxOXAdyvRf1cYBxs37ipgfYE60M |
| Feature 666481 (VUE label printing precedent) | https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/666481 |
