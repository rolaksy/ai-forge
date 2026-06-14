# TDD Codebase & Protocol Analysis — Feature 931220
## Auto Label | A5935 | MuK Label Robot | CSC VUE and PCS Classic | 26.1

**TDD PR:** [#42877](https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-KnowledgeBase/pullrequest/42877)  
**Feature ADO:** [#931220](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/931220)  
**TDD Branch:** `feature/BB-931220`  
**TDD File:** `/manual/docs/feature/2026/931220/feature-931220-tdd.md`  
**Analysis Date:** 2026-06-05  
**Repositories Analysed:** KP-MAP (`main`), KP-Xmit-KnowledgeBase (`feature/BB-931220`)

---

## Scope of This Analysis

Cross-analysis of `feature-931220-tdd.md` against:

- `/include/csdata.i` — CSDATA record layout (all field names, offsets, lengths)
- `/lib/pcslabelxml.f` — PCS VUE XML label pathway (`pcs_label_xml`, `create_label_element`)
- `/lbs/lbscsd.f` — Label CSDATA maintenance screen
- `/gen/xmglab.i` — XMG label print common variables
- `/prodsys/pcslabel.f`, `/prodsys/pcslabel.i` — PCS label field definitions
- `/fff/ffflabs.f`, `/prodsys/ffflabel.f` — Label format/FFF label logic
- Protocol claims and field mapping table in the TDD itself

---

## CRITICAL Issues

### C1 — `number_of_labels_per_pallet` Match Status is INCORRECT

**TDD claim (Objective ID Mappings table):** Match Status = `Correct`, note = _"Field exists in Kiwiplan. Default 3 at this site."_

**KP-MAP reality (`/include/csdata.i`):**

There is no CSDATA field named `cs_num_labels_pallet` or equivalent. The existing label-count fields are:

| CSDATA Field | Offset | Length | Column Name | Meaning |
|---|---|---|---|---|
| `cs_lbl_pallet$` | 548 | 1 byte | `labels_per_unit` | CSC/WIP load tags per pallet |
| `cs_fgs_pallet$` | 624 | 1 byte | `fgs_tags_pallet` | FGS load tags per pallet |
| `cs_stk_pallet$` | 676 | 1 byte | `stk_tags_pallet` | STK load tags per pallet |

The referenced **SCM 196681** relates to how the existing `cs_lbl_pallet$` is read for Opsigal reprints — it does not create a new field dedicated to MuK.

**Problems:**

1. **Wrong match status.** If the intent is to reuse `cs_lbl_pallet$`, the mapping must say so explicitly and justify the coupling to all other label printing logic that already reads this field.
2. **Default conflict.** The TDD says "Default 3 at this site", but the XML example in the TDD shows `<number_of_labels_per_pallet>2</number_of_labels_per_pallet>` with exactly 2 `<Label>` blocks. Is the site default 2 or 3? This directly determines how many PDF files are generated and how many `<Label>` blocks are in every OLP/RLP response.
3. **If a new field is needed** it must be added in the spare region (bytes 722–800 are confirmed spare in `csdata.i`) and will require changes to: `csdata.i`, `lbscsd.f` (screen), `sqcsdata.f`, `sqcsdat2.f`, `sqcsdat3.f`, `sqcsdat4.f`, `excsdata.f` (upgrade scripts).

**Required action:** Correct the match status. Identify the exact CSDATA field (existing or new). Resolve the 2 vs 3 default conflict.

---

## HIGH Issues

### H1 — New CSDATA Fields: Storage Layout Not Defined

The TDD identifies four new CSDATA fields per label slot: `GluePattern`, `PalPage`, `PosHori`, `PosVerti`.

**Confirmed via KP-MAP:** None exist anywhere in the codebase (zero search hits). They are genuinely new.

**What is missing from the TDD:**

1. **Maximum number of label slots.** The XML example has 2 `<Label>` blocks. The TDD scope section says "two label slots, allowing up to three sides". Is the max 2 or 3? This determines the number of CSDATA field groups to add.

2. **Byte offsets and field lengths.** The developer needs these to implement `csdata.i`. Estimated layout for 2 slots (starting from byte 722, the first confirmed spare byte):

   | Proposed Field | Length | Offset (2-slot) | Notes |
   |---|---|---|---|
   | `cs_muk_glue_pat_1$` | 1 byte | 722 | GluePattern slot 1, values 1–10 |
   | `cs_muk_glue_pat_2$` | 1 byte | 723 | GluePattern slot 2 |
   | `cs_muk_pal_page_1$` | 1 byte | 724 | PalPage slot 1 |
   | `cs_muk_pal_page_2$` | 1 byte | 725 | PalPage slot 2 |
   | `cs_muk_pos_hori_1$` | 1 byte | 726 | PosHori slot 1: L/M/R |
   | `cs_muk_pos_hori_2$` | 1 byte | 727 | PosHori slot 2: L/M/R |
   | `cs_muk_pos_verti_1$` | 2 bytes | 728–729 | PosVerti slot 1, mm (0–9999) |
   | `cs_muk_pos_verti_2$` | 2 bytes | 730–731 | PosVerti slot 2, mm (0–9999) |
   | `cs_muk_num_labels$` | 1 byte | 732 | number_of_labels_per_pallet (if new field needed) |

   This is a suggested layout — the TDD author must define and document the exact layout.

3. **Screen maintenance (`lbscsd.f`).** The label CSDATA maintenance screen must be extended to display and maintain these new fields. The TDD does not mention this. For a feature where "customer must configure values in Kiwiplan before the interface can function", this screen is critical.

4. **Upgrade scripts.** `sqcsdata.f` and related files must be updated. Not mentioned.

**Required action:** Add a CSDATA field layout table to the TDD specifying exact field names, byte offsets, lengths, and valid value ranges. Add `lbscsd.f` screen changes and upgrade script changes to the implementation scope.

---

### H2 — `number_of_pallets` Calculation Formula Not Specified

The TDD marks `number_of_pallets` as `Missing` and says _"Must be calculated at OL time. MuK uses it only to verify PDF count received."_

**No formula is given.**

From `csdata.i`: `cs_qty_pallet$` (offset 632–635, 4 bytes, `quantity_per_unit`) is the quantity per pallet. The most logical formula is:

```
number_of_pallets = CEILING(quantity / cs_qty_pallet$)
```

where `quantity` is received from MuK in the OL request.

**Unresolved questions:**

- Is this the intended formula? What if `cs_qty_pallet$` is zero or the CSDATA record does not exist for the order when OL arrives? The TDD must define the error behaviour (reject the OL? return `errorcode=1`?).
- For RLP: should `number_of_pallets` reflect the total order pallet count or always be 1 (since RLP is for a single residual pallet)? The XML example shows `RLP` process with `number_of_pallets>10</number_of_pallets>` — is that the total order count echoed back, or the count of remaining pallets?

**Required action:** Add the calculation formula to the TDD. Define error behaviour when CSDATA record is absent at OL time. Clarify `number_of_pallets` semantics in RLP context.

---

### H3 — PDF Generation Mechanism Not Identified

The TDD says Kiwiplan "generates one label PDF per `LabelNum` per pallet." 

**KP-MAP has no existing autonomous PDF-generation-and-FTP pathway.** The existing label infrastructure:

- `lab00` / `lbs00` — operator-driven label printing executable
- `pcslabelxml.f` (`pcs_label_xml`) — generates PCS VUE XML label requests (operator-triggered via `swpseq` / `pcs316`)
- `ffflabs.f`, `ffflabel.f` — label format file generation (also operator-driven)

None of these support: (a) autonomous triggering on receipt of an HTTP request, (b) PDF output format, or (c) direct FTP upload.

**Questions that must be answered in the TDD:**

1. What component generates the PDFs — a new XMT module, a new Java service, existing `lbs00` called via `procoff()`, or something else?
2. What label format/template is used for MuK PDFs? Is there a new label format code in CSDATA (e.g., a new `cs_muk_lab_fmt$` field), or does it reuse an existing format field?
3. Where are generated PDFs staged on the Kiwiplan server before FTP upload? Is there a dedicated temp directory? What is the cleanup policy after upload?
4. Who owns the label layout/design for A5935 — is a `.lbf` label format file already designed, or is that part of commissioning?

**Required action:** Add a "PDF Generation" subsection to the TDD identifying the generating component, label format source, and temp file lifecycle.

---

### H4 — Kiwiplan HTTP Server Implementation Not Specified

The TDD requires Kiwiplan to run an **inbound HTTP server on port 8090** to receive OL/RL POST requests from MuK.

**KP-MAP context:** The existing comms pathways are:
- Outbound: `java_comms_head()` / `write_jcomms_xml()` (Fortran→Java bridge for PCS VUE)
- Link connections: serial/socket via xmgen (`xmglopsig.f`, `xmglutil.i`)
- None support receiving inbound HTTP POST requests

**Questions that must be answered:**

1. Is the HTTP server a new Java/Spring service? A new XMT link configuration? An existing xmgen daemon extended with HTTP support?
2. Which process/executable hosts the HTTP listener — is it started by XMT, by a new systemd service, or as part of an existing daemon?
3. How is the HTTP server monitored for health (port open, process alive)?
4. Is there any authentication or IP whitelisting on the Kiwiplan HTTP server (the TDD says "no authentication required" — is this acceptable from a security standpoint given it accepts production data)?

**Required action:** Add an "HTTP Server Component" subsection to the TDD identifying the implementing component, startup mechanism, and monitoring approach.

---

## MEDIUM Issues

### M1 — `article_number` Source Not Identified

The TDD marks `article_number` as `Correct` and says "Echo back unchanged in OLP/RLP."

**There is no field named `article_number` in CSDATA.** The candidates are:
- `cs_po_key$` — 10 chars, production order key
- `cs_cust_item_no$` — 30 chars, customer's item number
- `cs_spec_num$` — 25 chars, specification number

The XML example shows `<article_number>123456789</article_number>` — a 9-digit value, which could be any of the above or something from a different table.

**Questions:**
- Is `article_number` purely echoed back from what MuK sent (i.e., Kiwiplan stores the inbound value and returns it), or does Kiwiplan resolve it from its own data?
- If resolved: which CSDATA/XDATA field provides it?

**Required action:** Clarify in the Objective ID Mappings table whether `article_number` is echoed or resolved, and if resolved, which Kiwiplan field supplies it.

---

### M2 — `order_number` Format Dependency on ADO 798569

The TDD marks `order_number` as `Correct` — "Must match what BGM sends to MuK."

**ADO 798569 (BGM link) is Backlog / not started.** The exact format BGM sends to MuK (numeric, alphanumeric, zero-padded, space-trimmed) is unknown until that work is done.

`cs_po_key$` is 10 characters. If MuK sends a 9-digit number without padding, a direct string comparison will fail unless trimming/formatting is applied.

**Required action:** Add a note in the TDD that `order_number` format validation is a dependency of ADO 798569. Flag as a risk item. Define the expected format (e.g., "right-justified, space-padded to 10 chars" or "numeric string, no padding") as soon as the BGM spec is available.

---

### M3 — FTP Credential Storage and FTPS Certificate Handling Not Specified

The TDD lists FTP Username/Password as "provided by MuK at commissioning" but does not specify:

- Where credentials are stored in Kiwiplan (XLATEP entry? A new config file? Site parameter?)
- How they are protected at rest (credentials in plaintext config files are a security risk)
- For FTPS: whether the MuK self-signed certificate must be imported/trusted, or whether cert verification is skipped — and if skipped, the security implication must be acknowledged

**Required action:** Add a "Credential Storage" note to the Configuration section. Confirm FTPS cert handling approach.

---

### M4 — Retry State Persistence and Alert Mechanism Unclear

The TDD says:
- FTP exhausted: "no XML ACK is sent — MuK must re-send OL/RL"
- HTTP ACK exhausted: "failure is logged and an alert is raised"

**Unresolved:**
- Is retry state held only in memory? If the Kiwiplan process crashes mid-retry, is the attempt silently lost?
- What is the "alert" mechanism for HTTP ACK failure — a visual message at the operator terminal, an XMIT log entry, an email notification, or something else?
- After FTP exhaustion, does Kiwiplan clean up any partially uploaded PDFs from the MuK FTP server before giving up?

**Required action:** Define the alert mechanism and specify whether retry state survives a process restart.

---

## LOW Issues

### L1 — `com_id` Generation and Duplicate Handling

The TDD says `com_id` is "sequential, unique per message" and "mirrored back unchanged."

**Questions:**
- Who generates `com_id` — MuK (Kiwiplan echoes it) or Kiwiplan (generates its own counter)? The TDD implies MuK generates it, but this should be stated explicitly.
- What happens if two OL requests arrive with the same `com_id` (MuK retry)? Should Kiwiplan treat this as a duplicate and suppress processing, or re-process?

**Required action:** State explicitly whether `com_id` is MuK-generated (echoed by KP) or KP-generated. Define duplicate handling.

---

### L2 — `pallet_quantity` in RLP vs `quantity` in OLP

The TDD says `pallet_quantity` is "MuK provides in RL; echoed back unchanged in RLP."

In the XML example the `RLP` response contains both `<quantity>5200</quantity>` (order quantity) and `<pallet_quantity>20</pallet_quantity>` (residual count).

**Question:** In the RLP response, does `<quantity>` reflect the original order quantity from the OL, or the residual quantity from the RL? The TDD does not address this field in the RLP direction.

---

### L3 — `pal_id` vs `pal_num` Distinction

The Objective ID Mappings table lists both `pal_id` (RL inbound) and `pal_num` (RL inbound) as separate fields, both marked `Not Applicable`.

The XML example shows only `<pal_num>10</pal_num>` — there is no `<pal_id>` element in the example.

**Questions:**
- Are `pal_id` and `pal_num` two different fields that both appear in RL requests, or are they the same field with two names?
- The note on `pal_id` says "per MuK confirmation not required in PDF filename" — does this mean `pal_id` exists in the protocol but KP ignores it, or it doesn't appear at all?

---

## Informational

### I1 — CSDATA Spare Region Confirmed Sufficient

From `csdata.i`: bytes 722–800 are spare (79 bytes available). This is sufficient for all proposed MuK fields (estimated 10–15 bytes for 2–3 label slots plus optional new label count field). The implementer should allocate from byte 722 upward.

### I2 — `cs_qty_pallet$` Confirmed Present

`cs_qty_pallet$` (offset 632–635, 4 bytes, `quantity_per_unit`) exists and is the natural source for pallet quantity calculation. Used extensively in `lbscsd.f` and `xmgact5.f`.

### I3 — No Existing MuK Code in KP-MAP

Searches for `muklab`, `muklabel`, `muk_label`, `MukLabel` return zero results — confirmed this is a genuinely new integration with no prior code base to build on.

### I4 — `pcslabelxml.f` is PCS VUE Only — Not a Template for MuK

`pcslabelxml.f` (`pcs_label_xml` / `create_label_element`) sends `REQUEST_LABELLING` / `ACTION_PCSLABEL` XML to PCS VUE via the existing Fortran-Java comms bridge. **This is not a usable template for the MuK interface** — the MuK interface uses a completely different XML schema, HTTP transport, and FTP file transfer that have no equivalent in this file.

---

## Summary of Required TDD Updates

| # | Severity | Item |
|---|----------|------|
| C1 | CRITICAL | Fix `number_of_labels_per_pallet` match status; identify exact CSDATA source field; resolve 2 vs 3 default |
| H1 | HIGH | Add CSDATA field layout table (names, offsets, lengths, valid values) for all new MuK fields; add `lbscsd.f` screen scope and upgrade script scope |
| H2 | HIGH | Add `number_of_pallets` calculation formula; define error behaviour when CSDATA absent at OL time; clarify RLP semantics |
| H3 | HIGH | Add PDF generation mechanism: component, label format source, temp file staging and cleanup |
| H4 | HIGH | Add HTTP server component description: implementation, startup, monitoring |
| M1 | MEDIUM | Clarify `article_number` — echoed or resolved; if resolved, identify source field |
| M2 | MEDIUM | Flag `order_number` format as ADO 798569 dependency risk |
| M3 | MEDIUM | Specify FTP credential storage and FTPS cert handling |
| M4 | MEDIUM | Define alert mechanism for retry exhaustion; clarify retry state persistence |
| L1 | LOW | Confirm `com_id` ownership (MuK-generated); define duplicate handling |
| L2 | LOW | Clarify `quantity` field semantics in RLP response |
| L3 | LOW | Resolve `pal_id` vs `pal_num` ambiguity in RL message |
