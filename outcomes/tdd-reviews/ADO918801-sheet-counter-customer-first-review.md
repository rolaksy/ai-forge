# ADO 918801 — Customer-First Re-Review: Kiwiplan Sheet Counter 1.0 | VUE

**Work Item:** [918801](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/918801)  
**TDD PR:** [#39158](https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-KnowledgeBase/pullrequest/39158)  
**Spike:** [972241](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/972241)  
**Customer:** Irani Papel E Embalagem SA (Vargem Bonita, Santa Catarina, Brazil)  
**Go-Live Date:** 2026-09-01 (< 4 months away)  
**Target Release:** 25.4 (planned)  
**Reviewed by:** Laks Yalamati  
**Review Date:** 2026-05-18  
**Framework:** TL-guided customer-first review (6-point framework)

---

## Review Framework: Think From the Customer's Shoes

> "We are reviewing a TDD. You should never think as a developer."  
> — TL guidance

The 6-point customer-first framework applied here:

1. What is the customer expectation?
2. Is there an existing link?
3. Check the existing installed link
4. Understand the current workflow
5. Relate back to the protocol document
6. Trace from business decision to technical implementation

---

## Point 1 — What Is the Customer Expectation?

### Who is this customer?

Irani Papel E Embalagem SA is a corrugated packaging manufacturer in Brazil. They are a **strategic account** (tagged `Cust-Strategic Account`) currently migrating from Kiwiplan Classic to **CSC VUE + PCS VUE**.

Their affected version today: `MAP: kiwi_9.20.01apr2019_210820`  
Go-live target: **September 1, 2026**

### What do they do TODAY that needs to keep working?

The sheet counter sits between the corrugator stacker and the shipping area. Irani Papel's operators rely on it for:

| # | What the customer does | System involved | Status after VUE? |
|---|----------------------|-----------------|-------------------|
| 1 | Forklift operator places a load label on the unit | Physical / Classic | No change |
| 2 | Sheet counter scans the barcode → counter screen shows order details (customer, order number, unit#, bundles/pallet, flute) | XMGEN + ULOADC (Classic) | Must be confirmed |
| 3 | Camera counts sheets → count sent to Kiwiplan → UNITQUE1.DA updated | XMGEN + UNITQUE (Classic) | Must be confirmed |
| 4 | **Load label prints automatically** (INV/AU Autoprint = Y) | XMGEN + Classic label printing | **Not confirmed — scoped out in TDD** |
| 5 | Bander operator screen (ult00 unitque=1) shows processed units in real time | Classic ULT screen + UNITQUE | Assumed Classic-side; not explicitly confirmed |
| 6 | PCS VUE production reports reflect the counted quantities | PCS VUE (Java) | **Not addressed in TDD** |

### The customer's real question (business language)

> *"When we go live on VUE in September, will our sheet counter still count sheets, print labels, and update production records exactly the way it does today?"*

The TDD currently only confirms items 2 and 3.  
Items 4, 5, and 6 are either scoped out or silent.

### What is the gap?

The TDD declares the feature "confined to validation/testing" and scopes out label printing and bander screen. But from the **customer's perspective**, these are not optional extras — they are core parts of the workflow that runs every production shift.

Specifically: the customer has **`INV/AU Autoprint = Y`**. This means Kiwiplan automatically prints the load label when the count is accepted. Removing this from scope without an explicit answer ("Classic-side label printing continues unchanged") leaves the customer's go-live at risk.

---

## Point 2 — Is There an Existing Link?

**Yes.** The Kiwiplan standard sheet counter protocol (`kiwi_sheetcounter_1.0`) is implemented and has been tested.

### Where does it live?

| Repo | Path | What it is |
|------|------|-----------|
| KP-MAP | `/scp/cntmess.scp` | Master message routing script |
| KP-MAP | `/scp/cntupda.scp` | UPD request message format |
| KP-MAP | `/scp/cntupdr.scp` | upd reply message format |
| KP-MAP | `/scp/cntcnta.scp` | CNT request message format |
| KP-MAP | `/scp/cntcntr.scp` | cnt reply (empty ACK) |
| KP-MAP | `/gen/xmgact5.f` | FORTRAN actions: `xmg_unitque_upd()`, `xmg_unitque_put()` |
| KP-Xmit-XmitTests | `/316276/P1/9.60/test.sh` | Automated test: standard flow |
| KP-Xmit-XmitTests | `/319958/P1/9.60.6/test.sh` | Automated test: USE_UNIT_BUNDLES_PER_PALLET |

### What do the tests cover?

Both test scripts (`316276` and `319958`) send real TCP messages to XMGEN and verify:

1. Both UPD and CNT messages are correctly identified/decoded
2. REP_SCAN (UPD request) decoded correctly
3. REP_INFO (upd reply) sent correctly with order details
4. **`unitque autoprint`** fires — the label **is** printed as part of the tested flow
5. REP_CNT (CNT request) decoded correctly
6. REP_CNT_ACK (cnt reply) sent correctly
7. Unit quantity updated in ULT screen
8. Bander screen (ult00 unitque=1) shows the counted unit

**Key finding:** The existing tests explicitly validate label printing (`VerifyScreenshot "Make sure that we print the label."`) and bander screen updates. These are NOT extras — they are core validated behaviors that exist today. The TDD's choice to scope these out is a business decision gap, not a technical gap.

The difference between `316276` and `319958` is that `319958` passes `def=USE_UNIT_BUNDLES_PER_PALLET` to xmgen. This is **exactly the Irani Papel site configuration** (`XMIT/XD` defines `USE_UNIT_BUNDLES_PER_PALLET`). Test `319958` is the most relevant existing test for this customer.

---

## Point 3 — Check the Existing Installed Link

### XMIT Configuration (Irani Papel site)

Extracted from the TDD and verified against KP-MAP source:

**XMIT/PO (Port Characteristics) — Key: SHTCNT**
```
Port Description:   SheetCounter Connection
Port name:          eagle:7764
Attributes:         /linger:0
Timeout (secs):     10
Protocol:           socgen
```

**XMIT/XG (Generic Xmitter Parameters) — Key: PARAMS**
```
Message summary script file:   cntmess.scp
Data summary script file:      obdata.scp
```

**XMIT/XD (Generic Define Words) — Key: PARAMS**
```
#define USE_UNIT_BUNDLES_PER_PALLET
#define ULTUPDATE
```

### What does each define word do?

| Define | Effect | Customer Impact |
|--------|--------|-----------------|
| `USE_UNIT_BUNDLES_PER_PALLET` | Changes the upd reply: sends `bundles_per_layer × layers_per_pallet` instead of `id:795 estimated units` | The counter screen shows correct physical bundle counts for Irani Papel's product configuration |
| `ULTUPDATE` | Enables real-time refresh of the ULT bander operator screen on every CNT event | Bander operator sees live unit status without manual refresh |

### TCP server/client topology

This was a source of confusion in the PR (Thread 317395). It is now resolved:

- **`cntmess.scp` defaults to `SOCGEN_MODE server`** (via `#ifndef SOCGEN_MODE #define SOCGEN_MODE server #endif`)
- `XMIT/PO port = eagle:7764` means XMGEN listens on port 7764 on the "eagle" (Kiwiplan server) host
- The **sheet counter connects TO eagle:7764** (sheet counter = TCP client; XMGEN = TCP server)
- This is confirmed by the Spike 972241 description: *"sheet-counter=client, XMGEN=server"*
- **The protocol document is correct.** Brian's initial PR statement that XMGEN is the client was an error that was corrected.

**Implication for VUE migration:** If XMGEN restarts during VUE deployment, the sheet counter will need to reconnect (it initiates). This is normal behavior. No firewall changes are needed for the sheet counter link direction.

### What is NOT in the installed link configuration?

The XMIT/XD does **not** define `SOCGEN_MODE client` — the default `server` mode from `cntmess.scp` is used as-is. This is consistent with the corrected topology above.

---

## Point 4 — Current Workflow

The end-to-end workflow at Irani Papel today, mapped to the technical layer:

```
[Operator loads unit onto conveyor]
        |
        v
[Sheet Counter: fixed scanner reads barcode]
        |
        | UPD message (barcode, 20 chars) over TCP
        | STX [UPD][barcode] ETX
        v
[XMGEN on eagle:7764 receives UPD]
        |
        | → script: cntupda.scp (decode UPD)
        | → action: unitque_put
        |   calls xmg_unitque_put() in xmgact5.f
        |   looks up order via ULOADC using barcode
        |
        | upd reply: customer(20) + order(20) + unit#(4)
        |            + bundles_per_pallet(2) [USE_UNIT_BUNDLES_PER_PALLET]
        |            + flute(3)
        v
[Sheet Counter: displays order details on screen]
[Operator: can verify correct order on counter screen]
        |
        v
[Sheet Counter: camera images the unit edge, calculates sheet count]
        |
        | CNT message (barcode 20 + sheet count 5) over same TCP connection
        | STX [CNT][barcode][count] ETX
        v
[XMGEN receives CNT]
        |
        | → script: cntcnta.scp (decode CNT)
        | → action: unitque_upd
        |   calls xmg_unitque_upd() in xmgact5.f
        |   - Checks UNITQUE1.DA print status gate (PRINTED / ACCEPTED)
        |   - If already PRINTED or ACCEPTED → do nothing (duplicate resend guard)
        |   - Updates UNITQUE1.DA with new quantity
        |   - INV/AU Autoprint=Y → calls xmg_unitque_can_autoprintL()
        |   - If qty within range → sets status=PRINTED, fires autoprint label
        |   - Updates ULOADC record
        |   - ULTUPDATE defined → triggers ult bander screen refresh
        |
        | cnt ACK reply (empty beyond command code)
        v
[Sheet Counter: receives ACK, clears for next unit]
[Bander screen (ult00 unitque=1): shows updated unit with counted quantity]
[Label printer: prints load label automatically (Autoprint=Y)]
```

### Timeout/resend behavior

- If XMGEN does not reply within **10 seconds**, the sheet counter resends the last message
- XMGEN handles duplicates via the `PRINTED`/`ACCEPTED` gate in `xmg_unitque_upd()`
- A repeated CNT for a unit that is already PRINTED → no second print, cnt ACK still returned

---

## Point 5 — Relate Back to the Protocol Document

Cross-check: does what's implemented match what `kiwi_sheetcounter_1.0` specifies?

| Protocol Spec | Implemented? | Source |
|--------------|--------------|--------|
| Transport: TCP/IP over LAN | ✅ | XMIT/PO socgen protocol |
| Connection model: sheet counter = client, Kiwiplan = server | ✅ (confirmed post-PR) | `cntmess.scp` SOCGEN_MODE server |
| Framing: STX (0x02) prefix, ETX (0x03) suffix | ✅ | `cntmess.scp`: SOCGEN_STX 02, SOCGEN_ETX 03 |
| Synchronous: one request, wait for reply | ✅ | Confirmed in TDD |
| Timeout: 10 seconds | ✅ | XMIT/PO timeout=10 |
| Resend: last message resent on timeout | ✅ | Duplicate guard in xmgact5.f |
| UPD request: barcode (20 chars) | ✅ | `cntupda.scp`: id:935 len:20 |
| upd reply: customer(20), order(20), unit#(4), units/bundles(2), flute(3) | ✅ | `cntupdr.scp` |
| CNT request: barcode(20) + sheet count(5) | ✅ | `cntcnta.scp`: id:935 len:20, id:961 len:5 |
| cnt reply: empty ACK | ✅ | `cntcntr.scp`: len:3 def:cnt only |
| Timeout default UPD reply: control number 99999, flute D | ⚠️ | Protocol spec mentions this; TDD notes it in operator workflow but doesn't verify in tests |

### Field format rules

The protocol specifies:
- Alphanumeric fields: left-justified with trailing spaces
- Numeric fields: right-justified with leading spaces

The SCP files use `o:A` (output format aligned) — this needs to be confirmed against the protocol alignment spec. The existing tests implicitly validate this through `VerifyScreenshot` of decoded messages, but the TDD doesn't call this out explicitly.

---

## Point 6 — Business Decision to Technical

### The business question Irani Papel is asking

> *"Will our sheet counting workflow work after we go to VUE?"*

### The technical answer

**YES** — with important conditions:

| Business Item | Technical Reality | Confirmed? |
|--------------|-------------------|-----------|
| Sheet counter sends UPD → gets order details | XMGEN is Classic-side; works unchanged in VUE deployment | ✅ Protocol validation only needed |
| Sheet count received → UNITQUE updated | `xmg_unitque_upd()` in FORTRAN xmgact5.f; Classic-side; no VUE change | ✅ |
| Load label prints automatically | `invau_autoprint_onL()` in xmgact5.f; Classic-side printer | ⚠️ **Works IF using Classic label printing. Not confirmed in TDD.** |
| Bander operator screen updates | `ult00 unitque=1` + ULTUPDATE define; Classic terminal | ⚠️ **Assumed to work; not explicitly confirmed in TDD for VUE deployment.** |
| Production counts visible in PCS VUE reports | Requires PCS VUE to consume UNITQUE/ULOADC data | ❌ **Not addressed in TDD or spike.** |

### The business gap the TDD creates

By scoping out items 4 and 5, the TDD creates a **documentation gap** at exactly the point where the customer needs clarity before go-live.

The correct answer to give the customer is:

> *"Your sheet counter protocol continues to work unchanged because XMGEN runs on the Classic side of the system. The counting, UNITQUE updates, label printing (Classic-side, Autoprint=Y), and bander screen all continue as today. No development changes are required. You do NOT need a VUE-specific label printing enhancement unless you want to change label formats to use VUE templates."*

If the team believes label printing does continue to work (most likely answer, since Classic XMGEN is unchanged), **the TDD should state this explicitly** rather than saying "out of scope."

"Out of scope" implies "not answered." The customer needs "answered, no change required."

---

## Summary of Findings

### What is correct in the TDD

- Protocol framing verified against `cntmess.scp` ✅
- Message fields verified against `cntupda/cntcnta/cntupdr/cntcntr.scp` ✅
- XMIT/PO, XMIT/XG, XMIT/XD configuration correctly documented ✅
- PRINTED/ACCEPTED duplicate guard noted (xmgact5.f confirmed) ✅
- TCP topology corrected during PR review (XMGEN=server, sheet counter=client) ✅
- Existing test evidence cited (316276, 319958) ✅
- Spike 972241 created for barcode-to-ULOADC validation ✅

### What is missing or ambiguous (customer perspective)

| # | Gap | Severity | From Customer's Shoes |
|---|-----|----------|-----------------------|
| 1 | Label printing (Autoprint=Y) scoped out without confirmation it works unchanged | **High** | Customer expects labels to print on every counted unit |
| 2 | Bander screen (ult00 unitque=1) not explicitly confirmed for VUE deployment | **Medium** | Bander operator uses this screen every shift |
| 3 | PCS VUE production report impact not addressed | **Medium** | Customer migrating to VUE for scheduling/reporting — they need counts in VUE |
| 4 | `USE_UNIT_BUNDLES_PER_PALLET` behavior in UPD reply not explained to customer | **Low** | Counter screen shows different field (bundles/pallet vs est. units) — does customer know this? |
| 5 | Timeout behavior: UPD reply with control=99999/flute=D not tested | **Low** | Operator sees "D" flute when Kiwiplan is slow — should be documented |
| 6 | Spike 972241 has no assigned owner or deadline | **Medium** | Go-live is September 2026 — who validates, by when? |

---

## Recommended Changes to the TDD

### Must-do before approval

**1. Replace "out of scope" for label printing with an explicit answer.**

Change:
> *Label handling changes in VUE are explicitly out of scope.*

To:
> *Label printing: XMGEN's Classic-side autoprint (`xmg_unitque_autoprint_label()`) continues to operate unchanged in a VUE deployment. No development changes are required. If the customer later requires VUE-environment label printing (e.g., VUE label templates), that is a separate enhancement (see Feature 666481 as precedent).*

**2. Add explicit confirmation for bander screen.**

Add:
> *Bander screen: `ult00 unitque=1` is a Classic terminal application that continues to function during and after VUE migration. `ULTUPDATE` define is retained in `XMIT/XD` to enable real-time screen refresh. No development changes required.*

**3. Add PCS VUE production report statement.**

Add:
> *PCS VUE production data: XMGEN updates Classic-side `UNITQUE*.DA` and `ULOADC`. Whether counted quantities are surfaced in PCS VUE production reports (Daily Run Sheet / Historical Production) should be confirmed by cross-referencing Feature 918387 (25.3 fix for Opsigal sheet counter) and the PCS VUE production data pipeline. If VUE reporting consumes from the same ULOADC source, no additional work is needed.*

**4. Assign Spike 972241.**

The spike (CNT.barcode → ULOADC resolution, using Irani Papel QA dataset) has no owner, no date. Add both before go-live.

### Nice-to-have

**5. Explain `USE_UNIT_BUNDLES_PER_PALLET` in plain English for the reader.**

> *This define changes the `upd` reply field from estimated unit count (`id:795`) to actual bundles-per-pallet (`id:3211 = bundles_per_layer × layers_per_pallet`). This reflects Irani Papel's physical unit configuration. The sheet counter display shows bundles/pallet instead of estimated units.*

**6. Note timeout/fallback behavior.**

> *If XMGEN does not reply to a UPD within 10 seconds, the sheet counter defaults control number to 99999 and flute to "D". The sheet counter will display this as an unknown unit. The operator must manually intervene.*

---

## Reference Links

| Resource | URL |
|----------|-----|
| ADO Work Item 918801 | https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/918801 |
| TDD PR #39158 | https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-KnowledgeBase/pullrequest/39158 |
| Spike 972241 | https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/972241 |
| cntmess.scp | https://dev.azure.com/advantive-devops/Advantive/_git/KP-MAP?path=/scp/cntmess.scp |
| Test 316276 (standard) | https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-XmitTests?path=/316276/P1/9.60/test.sh |
| Test 319958 (USE_UNIT_BUNDLES_PER_PALLET) | https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-XmitTests?path=/319958/P1/9.60.6/test.sh |
| Feature 666481 (VUE label precedent) | https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/666481 |
| Feature 918387 (Opsigal sheet counter 25.3) | https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/918387 |
| Irani Papel QA Data | https://advantiveadmin.sharepoint.com/:u:/s/CustomerSupport/IQDxckxGTi3TTpoxW8ni4ezuAaV9muCu4D7q4f9fmFGyqFA |
