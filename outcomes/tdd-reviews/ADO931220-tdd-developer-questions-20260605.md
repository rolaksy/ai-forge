# TDD Developer Questions — Feature 931220
## Auto Label | A5935 | MuK Label Robot | 26.1

**Role:** Reading as a developer who must implement from this TDD alone.  
**Date:** 2026-06-05  
**TDD:** `feature/BB-931220` → `/manual/docs/feature/2026/931220/feature-931220-tdd.md`

---

## Section: Business Outcome

> _"automatically receive label PDF files and positioning data from Kiwiplan"_

**Q1. What is "positioning data"?**  
This term is used in the business outcome but never formally defined until deep in the TDD. A developer reading top-to-bottom has no idea what it means here. Is it the `GluePattern`, `PalPage`, `PosHori`, `PosVerti` fields? Say so here.

> _"replacing a manual process in which operators generate PDFs at the Kiwiplan terminal"_

**Q2. What is the "Kiwiplan terminal"?**  
Is this the main CSC VUE screen? A specific program (e.g., `lab00`, `lbs00`)? The operator sitting at the corrugator? This needs to be named precisely — a dev needs to know which existing process is being automated/replaced so they know what code is changing vs what is new.

---

## Section: Business Outcomes Bullet Points

> _"What the operator and system can do after this work is complete that they cannot do today"_

**Q3. What does this section have to do with development?**  
This is marketing/product language. It belongs in a business requirements doc, not a TDD. A TDD should describe **what the system does technically** — which process starts, which file is written, which message is sent. None of that is here. This section gives a dev nothing to implement against.

---

## Section: Executive Summary

> _"Estimated Development: 10 weeks"_

**Q4. How was 10 weeks estimated?**  
The TDD has not been reviewed, the implementation approach has not been defined, the number of new CSDATA fields is unresolved, the PDF generation mechanism is unidentified, and there is no existing template for this interface type. On what basis was this estimate made? A number without a breakdown is not an estimate — it is a guess. A work breakdown (HTTP server, FTP client, XML parser, CSDATA schema, screen changes, upgrade scripts, simulator, testing) should back this up.

> _"Module: Kiwiplan / VUE / XMT"_

**Q5. Which module owns this work?**  
"Kiwiplan / VUE / XMT" covers almost everything. Which specific executables or services are being changed? Is this work in xmgen (Fortran), a Java service, CSC VUE, or all three? The developer assigned to this needs to know which codebase they are working in.

---

## Section: Background

> _"The layout (A5935) includes two label slots, allowing up to three sides of a pallet to be labeled."_

**Q6. What does "two label slots, three sides" mean — how many PDFs and `<Label>` blocks do I generate?**  
This sentence is contradictory to a dev. Two slots → two PDFs per pallet? Or up to three? The XML example shows exactly 2 `<Label>` blocks. Is the maximum always 2, or can it be 3? The number of slots directly controls:
- How many PDFs are generated per pallet
- How many CSDATA field groups to add (`GluePattern_1/2/3`, etc.)
- How many `<Label>` blocks appear in OLP/RLP

This must be an exact number, not "up to".

---

## Section: Scope — In Scope

> _"Bidirectional XML-over-HTTP interface between Kiwiplan and MuK IPC (OL, OLP, RL, RLP messages)"_

**Q7. What are the HTTP timeouts?**  
No timeout is specified anywhere in the TDD for either direction (Kiwiplan waiting for MuK's OL/RL to arrive, or Kiwiplan waiting for its OLP/RLP POST to be accepted). What is the connection timeout? What is the read/response timeout? Without these a developer will either hard-code a guess or leave it unconfigured.

**Q8. What HTTP status codes does Kiwiplan check when sending OLP/RLP to MuK?**  
When Kiwiplan POSTs the OLP/RLP response to MuK's HTTP server, what HTTP status code(s) does MuK return on success? On error? Does a `200 OK` with `errorcode=1` in the XML body count as a failure or a success? How does Kiwiplan distinguish "MuK received and accepted" from "MuK received but rejected"?

**Q9. What HTTP status code does Kiwiplan return to MuK when it receives OL/RL?**  
When MuK POSTs an OL or RL to Kiwiplan's HTTP server, what HTTP status code should Kiwiplan immediately return? `200 OK` immediately (before FTP upload)? Or does Kiwiplan hold the connection open until FTP upload + XML ACK is complete and then return `200`? The order matters — if Kiwiplan returns `200` immediately but then fails FTP, MuK thinks the request succeeded.

> _"Retry logic (up to 2 retries) for both HTTP XML and FTP transfers"_

**Q10. What is the retry delay between attempts?**  
Retry 2 times — but how long does Kiwiplan wait between retries? Immediately? After 5 seconds? After 30 seconds? Without a delay the retries may all fail for the same transient reason (e.g., network blip).

> _"New CSDATA fields for multi-slot label positioning (GluePattern, PalPage, PosHori, PosVerti) — one set per label slot per product"_

**Q11. How many slots? What are the exact CSDATA field names and byte offsets?**  
"One set per label slot" — but the maximum number of slots is never stated definitively (see Q6). A developer cannot extend `csdata.i` without knowing: field names, byte offsets, data types, and lengths for every new field. None of this is in the TDD.

**Q12. Which screen do these new CSDATA fields appear on for the operator to configure?**  
The TDD says "customer must configure in Kiwiplan" but never identifies which screen, which program, or which menu path. Is it `lbscsd` (label CSDATA maintenance)? Something else? A dev needs to know which screen to extend.

> _"MuK simulator module for development and testing (no vendor simulator available)"_

**Q13. What must the simulator do exactly?**  
Scope says "MuK simulator module" is in scope, but there is no specification of what it must simulate. Must it:
- Accept HTTP POST on port 8085?
- Send OL/RL requests to Kiwiplan on port 8090?
- Act as an FTP server to receive PDF uploads?
- Validate PDF filenames?

Without a simulator spec, a dev cannot build it. This is effectively a second mini-feature with its own requirements.

---

## Section: New Link Architecture — HTTP

> _"No authentication required."_

**Q14. Is this a security sign-off or an assumption?**  
Was the decision to have no authentication explicitly reviewed and accepted by security/architecture, or is this just "MuK didn't ask for it"? If Kiwiplan's HTTP server on port 8090 has no authentication, any machine on the network can POST fabricated OL requests and trigger PDF generation and FTP uploads. Was this risk assessed?

> _"On transmission error: retry up to 2 times for both XML and PDF."_

**Q15. What counts as a "transmission error"?**  
For HTTP: is it a TCP connection failure, an HTTP `5xx` response, an HTTP `4xx` response, a timeout? All of the above? For FTP: is it a failed login, a failed STOR command, a partial transfer? The developer needs to know exactly which error conditions trigger a retry vs which are fatal.

---

## Section: New Link Architecture — FTP

> _"Kiwiplan uploads PDF files to the MuK IPC directory (determined by FTP server; client cannot select directory)."_

**Q16. Does Kiwiplan need to verify the file exists on MuK's FTP server after upload?**  
After a STOR command succeeds, should Kiwiplan verify the file is there (e.g., with a SIZE or LIST command)? Or is FTP success response sufficient? This matters for retry logic — if the STOR response is lost in transit but the file was written, a retry would overwrite it, which is probably fine, but should be confirmed.

> _"FTP credentials: to be announced by MuK at short notice."_

**Q17. Where are FTP credentials stored in Kiwiplan?**  
The TDD says credentials are "to be announced" but never says where they will be stored. XLATEP? A config file? A site parameter table? A developer implementing the FTP client needs to know where to read the username and password from at runtime.

> _"FTPS (self-signed certificate) is possible."_

**Q18. For FTPS: does Kiwiplan accept self-signed certs without verification, or must the cert be imported?**  
If Kiwiplan skips cert verification for FTPS, that must be an explicit design decision. If it must import the cert, who does that at commissioning and how?

---

## Section: TO-BE Workflow — Standard Order Flow

> _"Step 4: Kiwiplan looks up order data and label configuration."_

**Q19. What happens if the order does not exist in Kiwiplan when OL arrives?**  
MuK sends OL when the operator starts the order at the MuK HMI. But what if the order has not been created in Kiwiplan yet, or the CSDATA record is missing? Should Kiwiplan return `errorcode=1` in the OLP? Hold and wait? Reject silently? This is a real operational scenario and must be defined.

> _"Step 5: Kiwiplan generates one label PDF per LabelNum (1…N) per pallet"_

**Q20. What generates the PDF?**  
This is the most fundamental unanswered question in the entire TDD. The word "generates" hides enormous implementation complexity. Does Kiwiplan:
- Call an existing label printing program (`lab00`/`lbs00`) in batch mode?
- Use a new rendering component?
- Call a Java/Spring PDF service?
- Use FFF label format files?

Without knowing what generates the PDF, a developer cannot start.

**Q21. What label format/template is used for MuK PDFs?**  
Label format in Kiwiplan is configured via LBFORM (label format files, `.lbf`). Which label format code is used for MuK? Is it an existing format, or does a new one need to be created? Who creates the label layout (developer or PS)? If it uses the same `cs_corr_wip$`/`cs_wip_fgs$` format codes from CSDATA, which one applies here?

**Q22. Where are PDFs temporarily stored before FTP upload?**  
PDFs must be written somewhere on the Kiwiplan server before being FTP-uploaded to MuK. What directory? Is it a temp directory? Is it cleaned up after upload? What if the disk is full?

**Q23. For an order of N pallets, how many PDFs are generated in total?**  
If there are 10 pallets and 2 label slots each, that is 20 PDFs. For a large order (e.g., 500 pallets), that is 1000 PDFs generated and uploaded before OLP is sent. Is there a performance concern? Is there a maximum? Does this happen synchronously (blocking MuK's OL request) or asynchronously?

> _"Step 7: OLP contains ... a `<Label>` block per label slot with GluePattern, PalPage, PosHori, PosVerti"_

**Q24. Are the `<Label>` blocks per pallet the same for every pallet in the order, or can they differ per pallet?**  
The OLP example shows 2 `<Label>` blocks, and the TDD says these come from CSDATA (per product). So all pallets in an order would have the same `GluePattern`, `PalPage`, `PosHori`, `PosVerti`. Is that correct? Or does the last (residual) pallet have different positioning?

---

## Section: TO-BE Workflow — Residual Pallet Flow

> _"MuK sends an RL XML request to Kiwiplan with pal_num (pallet number) and pallet_quantity (remaining sheet count)."_

**Q25. What does Kiwiplan do with `pal_num` in the RL request?**  
The mapping table marks `pal_num` as "Not Applicable — used for residual pallet PDF lookup." But how? Kiwiplan already generated all pallet PDFs on OL (step 5). So does RL trigger generation of a new PDF for the residual pallet, or does Kiwiplan re-use the already-generated file with the matching `pal_num` in the filename? If re-using, what if the file was already deleted?

**Q26. Does the RL residual pallet get a new PDF, or is the PDF from OL re-sent?**  
If a new PDF is generated for the residual pallet, the sheet count on the label will differ from the full-pallet labels. Does the label template support a dynamic quantity field? Who controls the quantity printed on the label?

> _"MuK checks pallet height: if height ≥ threshold: prints and attaches. If height < threshold: prints only."_

**Q27. Does Kiwiplan need to know about the height threshold, or is this purely MuK-side logic?**  
This is mentioned in the TDD but there is no indication that Kiwiplan does anything with it. If it is purely MuK-side, why is it in the TDD? If Kiwiplan needs to provide height data, which field provides it?

---

## Section: Error / Retry Flow

> _"On FTP upload failure: no XML ACK is sent — MuK must re-send the OL/RL to trigger a new attempt."_

**Q28. What happens to the partially uploaded PDFs on MuK's FTP server after an exhausted retry?**  
If 8 out of 20 PDFs were uploaded before retries were exhausted, MuK's FTP server has 8 orphaned files. When MuK re-sends OL, does Kiwiplan overwrite them, or upload all 20 again? Is there a cleanup step?

> _"On HTTP ACK failure: failure is logged and an alert is raised."_

**Q29. What does "an alert is raised" mean?**  
This is meaningless without specifics. Does it:
- Display a message on the Kiwiplan operator terminal?
- Write to the xmgen log file?
- Send an email?
- Raise a Kiwiplan alarm?

A developer cannot implement an "alert" without knowing what mechanism to use.

**Q30. At the point where HTTP ACK fails after all retries, the PDFs are already on MuK's FTP server. Does MuK still use them?**  
If Kiwiplan uploaded all PDFs successfully but the OLP HTTP ACK failed, MuK never gets the XML positioning data. The PDFs are there but MuK does not know the `GluePattern`, `PalPage`, `PosHori`, `PosVerti`. What does MuK do in this state? Does it timeout and re-send OL? Is there an inconsistency risk (PDFs present, positioning missing)?

---

## Section: Configuration Details

> _"number_of_labels_per_pallet | Labels per pallet | Customer to configure in Kiwiplan"_

**Q31. Which exact Kiwiplan field/screen does the customer configure this in?**  
The config table says "customer to configure in Kiwiplan" but does not say where. Same for `GluePattern`, `PalPage`, `PosHori`, `PosVerti`. For each configurable item, the TDD must state: which program, which screen/menu, which field on that screen.

> _"Retry Count | 2 | Integer | Dev"_

**Q32. Is retry count configurable at runtime, or is it a compile-time constant?**  
"Set By: Dev" implies it is hard-coded. Should it be in XLATEP or a config file so Support can change it without a code rebuild? For a new interface with unknown reliability, this seems like it should be configurable.

---

## Section: Protocol Messages — XML Structure

**Q33. The XML example is labelled `<process>RLP</process>` but contains fields from both OLP and RL/RLP — is this the canonical example for all message types?**  
The single XML example appears to show every possible field together (`quantity`, `number_of_pallets`, `pallet_quantity`, `pal_num`, both `<Label>` blocks). In practice:
- OL inbound will not contain `<Label>` blocks
- OLP outbound will not contain `pallet_quantity` or `pal_num`
- RL inbound will not contain `number_of_pallets`

A developer needs a separate example for each of the 4 message types (OL, OLP, RL, RLP), showing only the fields present in that message. One composite example is not sufficient to implement a parser.

**Q34. What is the XML encoding and line ending format?**  
The example shows `encoding="iso-8859-1"`. Is this mandatory? Will MuK reject UTF-8? Must Kiwiplan's HTTP server also accept iso-8859-1 encoded POST bodies from MuK?

**Q35. What is the HTTP `Content-Type` header for the XML POST body?**  
Should it be `text/xml`, `application/xml`, or `application/x-www-form-urlencoded`? What does MuK's HTTP server expect? What does Kiwiplan's HTTP server expect? Without this a dev will guess and the integration may fail.

**Q36. What is the maximum size of an OLP XML message?**  
For a large order with many pallets and 2 label slots each, the `<Label>` blocks repeat per pallet. For 500 pallets × 2 slots = 1000 `<Label>` blocks in one OLP message. Does MuK's HTTP server have a body size limit? Is there a paging mechanism?

---

## Section: Objective ID Mappings

**Q37. `order_number` is marked `Correct` — but which Kiwiplan field exactly?**  
`cs_po_key$` is 10 chars. If MuK sends `123456789` (9 digits, no padding), does Kiwiplan strip whitespace before matching? Does it left/right-pad? The format must match exactly what the BGM sends to MuK, and ADO 798569 (BGM link) has not started yet, so this "Correct" status cannot be validated.

**Q38. `article_number` is marked `Correct` and "echo back unchanged" — so Kiwiplan never validates it against its own data?**  
If `article_number` is purely echoed, the TDD should say which field in the inbound XML is stored temporarily and echoed. If it is never validated, what happens if MuK sends a wrong article number? Kiwiplan just echoes back an incorrect value — is that acceptable?

**Q39. `number_of_labels_per_pallet` is marked `Correct` — which exact CSDATA field maps to this?**  
The TDD says "field exists in Kiwiplan" but does not name it. The closest in CSDATA is `cs_lbl_pallet$` (1 byte, `labels_per_unit`). Is that it? If so, the TDD must say so explicitly. The TDD also says "Default 3" but the XML example shows `2`. Which is correct for this site?

---

## Section: PDF Label File Naming

> _"`OLP_[order_number]_[pallet_seq]_[LabelNum].pdf`"_

**Q40. What is the field width/padding of each segment?**  
Is `pallet_seq` zero-padded (e.g., `001`) or not (e.g., `1`)? If the order has 10 pallets, does the filename for pallet 1 have `_1_` or `_01_` or `_001_`? MuK matches files by name, so the format must be exact. Same question for `LabelNum`.

**Q41. What is the maximum filename length and does it fit within FTP path limits?**  
If `order_number` is up to 10 chars, `pallet_seq` up to 3 digits, `LabelNum` 1 digit: `OLP_1234567890_999_2.pdf` = 24 chars. That is fine. But confirm there is no truncation.

---

## Section: Link Simulator

> _"No simulator available from MuK. Testing must be performed on the actual live system once the interface is ready."_

**Q42. The scope says "MuK simulator module" is in scope — but this section says testing on live system only. Which is it?**  
Scope (page 1) says a simulator will be built. This section says testing on the live system. These are contradictory. If a simulator is being built, what must it do? If no simulator, how does a developer test during development before the live system is available?

---

## Section: SCM and KALL

> _"SCM 196681 — Directly relevant: MuK feature uses `number_of_labels_per_pallet` from the same field."_

**Q43. SCM 196681 resolves Opsigal label count reading — what does that have to do with MuK?**  
SCM 196681 fixed how `cs_lbl_pallet$` is read for Opsigal sheet counter reprints. The TDD claims this is "directly relevant" to MuK's `number_of_labels_per_pallet`. But Opsigal and MuK are completely different interfaces. The relevance claim needs to be explained. Does MuK re-use the same Opsigal label count code path, or is this just noting that the same CSDATA field is used?

---

## Overall TDD Gaps — Summary for Author

| # | Section | Question |
|---|---------|----------|
| Q1 | Business Outcome | Define "positioning data" at first use |
| Q2 | Business Outcome | Name the specific program/screen being replaced ("Kiwiplan terminal") |
| Q3 | Business Outcomes bullets | Remove marketing language — replace with technical behaviour |
| Q4 | Executive Summary | Provide estimate breakdown by work area |
| Q5 | Executive Summary | Name specific executables/services being changed |
| Q6 | Background | State exact maximum number of label slots (2 or 3) |
| Q7 | Architecture | Specify HTTP connection and read timeouts |
| Q8 | Architecture | Specify HTTP status codes Kiwiplan checks on OLP/RLP POST to MuK |
| Q9 | Architecture | Specify HTTP status code Kiwiplan returns to MuK on receiving OL/RL |
| Q10 | Architecture | Specify retry delay interval |
| Q11 | Scope | List exact CSDATA field names, byte offsets, lengths for all new fields |
| Q12 | Scope | Name the screen where new fields are configured |
| Q13 | Scope | Provide simulator specification (what it must send/receive/validate) |
| Q14 | Architecture | Confirm no-auth decision was security-reviewed |
| Q15 | Architecture | Define what error conditions trigger retry vs fatal for both HTTP and FTP |
| Q16 | Architecture | Define whether Kiwiplan verifies file presence after FTP upload |
| Q17 | Architecture | Name where FTP credentials are stored at runtime |
| Q18 | Architecture | Define FTPS cert validation behaviour |
| Q19 | Workflow | Define behaviour when order not found in Kiwiplan at OL time |
| Q20 | Workflow | Identify what component generates PDFs |
| Q21 | Workflow | Identify label format/template used for MuK PDFs |
| Q22 | Workflow | Define PDF temp storage location and cleanup policy |
| Q23 | Workflow | Address performance for large orders (500+ pallets) |
| Q24 | Workflow | Confirm `<Label>` block positioning is identical for all pallets in an order |
| Q25 | Workflow | Explain how `pal_num` from RL maps to a specific PDF |
| Q26 | Workflow | Confirm whether RL generates a new PDF or re-sends existing |
| Q27 | Workflow | Clarify if pallet height threshold is relevant to Kiwiplan at all |
| Q28 | Error Flow | Define cleanup of orphaned PDFs after retry exhaustion |
| Q29 | Error Flow | Define what "alert" mechanism means technically |
| Q30 | Error Flow | Define MuK state when PDFs uploaded but OLP ACK failed |
| Q31 | Config | For every customer-configured field, name the screen and field in Kiwiplan |
| Q32 | Config | Clarify if retry count is hard-coded or runtime configurable |
| Q33 | Protocol | Provide separate XML examples for each of OL, OLP, RL, RLP |
| Q34 | Protocol | Confirm XML encoding (iso-8859-1) is mandatory for both directions |
| Q35 | Protocol | Specify HTTP Content-Type header for XML POST bodies |
| Q36 | Protocol | Address OLP message size for large orders |
| Q37 | Mapping | Name exact Kiwiplan field for `order_number` and specify whitespace/padding handling |
| Q38 | Mapping | Confirm `article_number` is purely echoed with no validation |
| Q39 | Mapping | Name the exact CSDATA field for `number_of_labels_per_pallet`; resolve default 2 vs 3 |
| Q40 | Naming | Specify zero-padding format for `pallet_seq` and `LabelNum` in PDF filenames |
| Q41 | Naming | Confirm filename length is within FTP path limits |
| Q42 | Simulator | Resolve contradiction: simulator in scope (Scope section) vs test on live only (Simulator section) |
| Q43 | SCM/KALL | Explain relevance of SCM 196681 (Opsigal) to MuK interface |
