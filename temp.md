I'll execute the PR review workflow for PR #43768. Let me start with Step 1.

Now let me fetch PR threads and the diff simultaneously:

Good. Now let me check the repo locally and fetch the work item in parallel:

Repo exists. Now updating the branch and fetching the knowledge base reference doc in parallel:

Now let me read all the new source files in the feature branch:

Now let me read the remaining new files:





Now I have all the data needed to compile the full review. Let me also look at the reference doc linked in the work item and check the auth configurator change:





Now let me examine a few more specifics — the `CscService.shiftSplitSetup` signature vs the service call, and the auth configurator redundancy:

I now have all the context needed. Let me produce the full review report.

---

# PR Review Report — PR #43768

**Title:** [26.3/main] Implement shift-split feedback API
**Author:** Laks Yalamati
**Repo:** `KP-MapJava` | **Branch:** `feature/ado-977196-csc-shift-split-api` → `main`
**Work Item:** [ADO #977196 — CSC Shift-Split API](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/977196)
**Status:** Active | 1 approval (Kevin Liang)

---

## Section 1 — Summary

This PR introduces a new REST endpoint `POST /api/v1/corrugators/{corrugatorNumber}/feedback/shift-split` to `kp-csc-service`. The implementation mirrors the existing comms handler (`CorrugatorFeedbackUpdateRequestHandler`) for the shift-split operation. The overall structure is sound and correctly delegates to `CscService.shiftSplitSetup()`. Several issues are identified below ranging from correctness bugs to test coverage gaps.

---

## Section 2 — Existing PR Thread Review

| Thread | File | Status | Assessment |
|---|---|---|---|
| 352685 | `CorrugatorFeedbackService.java:77` | Resolved (WontFix) | Aikido flagged ordering of state check vs feedback fetch. **Verified:** In the current code, the state check now correctly precedes the feedback fetch (lines 235–242 before line 245). Thread was addressed. ✅ |
| 354363 | `CorrugatorFeedbackService.java:87` | Resolved (WontFix) | Aikido flagged `shiftSplitTime` future check after feedback fetch. **Verified:** In the current code, this check (lines 254–259) now comes after [getLatestSetupFeedback](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:426:2-438:3) which is required — the `startTime` is derived from the feedback (line 249). The ordering is now correct by logic necessity. ✅ |
| 354425 | `CorrugatorFeedbackService.java:647` | **Active / No comments** | An empty thread with no comment body — appears to be a spurious/accidental thread with no content. Cannot review intent. ⚠️ |
| 354426 | `CorrugatorFeedbackService.java:646–649` | Resolved (WontFix) | Aikido suggested `stream().max()` over `sort()`. **Verified:** The current [getLatestSetupFeedback(SetupRun)](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:426:2-438:3) implementation at lines 646–649 already uses `stream().max(...)`. The earlier [getLatestSetupFeedback(Long)](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:426:2-438:3) at lines 427–439 also uses `stream().max()`. The Aikido suggestion was already applied. ✅ |

---

## Section 3 — Context & Knowledge Base

- **AC Status:** No formal acceptance criteria are present on ADO #977196 (Achu Vasudevan requested AC be added — unanswered as of review). AC was derived from the resolution notes and PR description.
- **Derived AC:**
  1. `POST /api/v1/corrugators/{corrugatorNumber}/feedback/shift-split` accepts `setupNumber` and `shiftSplitTime` and returns `newSetupNumber` and `newProgramNumber`.
  2. Validates that the setup is in `PROCESSING` or `AWAITING_RETURN` state — returns 409 otherwise.
  3. Validates that `shiftSplitTime` is not in the future — returns 409.
  4. Returns 404 if corrugator or setup run not found.
- **Comms handler reference:** `CorrugatorFeedbackUpdateRequestHandler.java:156–157` uses the same `shiftSplitSetup` call signature (`corrugatorId, machineId, setupRunId, startTime, shiftSplitTime, Duration(0), totalLinealRan, currentTime, LEGACY_SHIFT_SPLIT`). The new service call at `CorrugatorFeedbackService.java:263–272` matches exactly. ✅
- **KB:** Limited protocol documentation for the CSC shift-split in the knowledge base. Review is code-only.

---

## Section 4 — Code Review Findings

### 🔴 Critical Issues

**C-001 — Auth Bypass Pattern Is Redundant and Could Be a Future Mismatch**

In `@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/config/auth/CscAuthenticationPatternConfigurator.java:22-23`:

```@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/config/auth/CscAuthenticationPatternConfigurator.java:22-23
                            .mvcMatchers("/api/v1/corrugators/{corrugatorNumber}/feedback/shift-split")
                            .mvcMatchers("/api/v1/corrugators/{corrugatorNumber}/feedback/**")
```

The specific matcher for `/feedback/shift-split` (line 22) is **redundant** — it is already covered by the wildcard `/feedback/**` on line 23. Spring Security evaluates matchers in declaration order; the specific one being listed _before_ the wildcard means it has no practical effect. This is harmless now but could cause confusion or diverge if the wildcard is ever removed. **Recommend removing line 22.**

> This is a low-risk inconsistency but is unnecessary code.

---

**C-002 — [getActiveLightweightCorrugator](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:610:2-620:3) Makes Two Service Calls Instead of One**

In `@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:611-620`:

```@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:611-620
  private LightweightCorrugator getActiveLightweightCorrugator(Integer corrugatorNumber) {
    try {
      Corrugator fullCorrugator =
              cscService.getActiveCorrugatorByCorrugatorNumber(corrugatorNumber);
      // getLightweightCorrugator from the full corrugator via its id
      return cscService.getLightweightCorrugator(fullCorrugator.getId());
    } catch (CorrugatorNumberNotFoundException | CscServiceException e) {
      String message = String.format("Corrugator with number '%d' not found or is retired.", corrugatorNumber);
      throw new CorrugatorNotFoundException(message, e);
    }
  }
```

This fetches the full `Corrugator` object just to extract its ID in order to then fetch a `LightweightCorrugator`. The comms handler (`CorrugatorFeedbackUpdateRequestHandler`) only uses the `LightweightCorrugator`. The reason for the two-step approach is not documented. If `CscService` has a method that directly accepts `corrugatorNumber` and returns a `LightweightCorrugator`, this double call is wasteful. **If no such method exists, a comment justifying the two-step approach should be added.**

---

### 🟡 Medium Issues

**M-001 — [performShiftSplit](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:215:2-284:3) Catches `XmgenCscServiceException` and Wraps in `RuntimeException` — Loses Error Semantics**

In `@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:280-284`:

```@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:280-284
    } catch (XmgenCscServiceException e) {
      logger.error("Shift split failed for corrugator {} setup {}: {}",
              corrugatorNumber, request.getSetupNumber(), e.getMessage(), e);
      throw new RuntimeException("Shift split operation failed: " + e.getMessage(), e);
    }
```

Throwing a bare `RuntimeException` from a service layer is problematic:
- The [CscControllerExceptionHandler](cci:2://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/exception/handler/CscControllerExceptionHandler.java:35:0-507:1) has no handler for `RuntimeException`, meaning this will propagate as an unhandled exception resulting in a 500 with no structured error body.
- The existing pattern in this service wraps unexpected exceptions in `CscServiceException` (see [updateFeedback](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:68:2-104:3), [completeFeedback](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:106:2-213:3)). This should follow the same pattern — throw `CscServiceException` or a dedicated checked/unchecked exception that the handler understands.

**Recommend:** Wrap in `CscServiceException` or a new `ShiftSplitFailedException` that maps to HTTP 500 in the exception handler.

---

**M-002 — `shiftSplitTime` Parsed Using `ZoneId.systemDefault()` — Timezone Ambiguity**

In `@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:656-659`:

```@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:656-659
  private Time parseShiftSplitTime(LocalDateTime shiftSplitTime) {
    long epochMs = shiftSplitTime.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
    return new Time(epochMs);
  }
```

The `@Schema` annotation on `ShiftSplitRequest.shiftSplitTime` states _"treated as server local time"_, which is honoured by using `ZoneId.systemDefault()`. However, this is only safe if the server and corrugator are always in the same timezone. The comms handler uses `new Time(shiftSplitDateTime.getTime())` where `shiftSplitDateTime` is a `java.util.Date` (already epoch-based). This approach is consistent with the legacy comms handler but the timezone assumption is implicit. **At minimum, this contract should be documented in the method Javadoc and the Swagger `description` should clearly state what timezone is expected.**

The Swagger description says _"no timezone — treated as server local time"_ which is correct, but the method itself lacks a comment explaining the ZoneId choice.

---

**M-003 — `SHIFT_SPLIT_STATUS_FILTER` Includes `SetupStatus.FINISHED` but [performShiftSplit](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:215:2-284:3) Only Accepts `PROCESSING` or `AWAITING_RETURN`**

In `@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:58-62`:

```@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:58-62
  private static final List<SetupStatus> SHIFT_SPLIT_STATUS_FILTER = Arrays.asList(
          SetupStatus.ISSUED,
          SetupStatus.PROCESSING,
          SetupStatus.FINISHED
  );
```

[getSetupRun()](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:622:2-636:3) at line 625 queries using `SHIFT_SPLIT_STATUS_FILTER`, which includes `ISSUED` and `FINISHED`. But [performShiftSplit()](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:215:2-284:3) then immediately rejects anything that isn't `PROCESSING` or `AWAITING_RETURN` (lines 235–242). This means:
- A setup in `ISSUED` or `FINISHED` state will be found by the DB query, only to be rejected at the state check — producing a misleading 409 (`NOT_PROC_SHIFT`) instead of a 404 (setup not found).
- The `AWAITING_RETURN` status check at line 236 uses `TransmissionStatus`, not `SetupStatus`, so `AWAITING_RETURN` would not appear in the filter at all (correct). But `FINISHED` and `ISSUED` setups will still be returned unnecessarily.

**Recommend:** Narrow `SHIFT_SPLIT_STATUS_FILTER` to only `SetupStatus.PROCESSING` (the relevant statuses for the query), and handle `AWAITING_RETURN` via the transmission status check afterward. If `ISSUED`/`FINISHED` must be included for some business reason, document why.

---

**M-004 — `new Time()` vs `Time.now()` Inconsistency**

In `@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:251`:

```@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:251
    Time currentTime = new Time();
```

In the same file, [updateFeedback](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:68:2-104:3) (line 86) uses `Time.now()`. Both may be equivalent depending on the `Time` class implementation, but using two different idioms for the same thing in the same class is inconsistent and may confuse maintainers. **Recommend using the consistent `Time.now()` pattern.**

---

### 🟢 Minor Issues

**N-001 — Test Class Missing Tests for [shiftSplit](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/controller/v1/CorrugatorFeedbackController.java:117:2-141:3) Endpoint**

The test file [TestCorrugatorFeedbackController.java](cci:7://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/testsrc/com/kiwiplan/csc/rest/controller/v1/TestCorrugatorFeedbackController.java:0:0-0:0) only contains tests for [updateFeedback](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:68:2-104:3) and [completeFeedback](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:106:2-213:3):

```@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/testsrc/com/kiwiplan/csc/rest/controller/v1/TestCorrugatorFeedbackController.java:1-75
```

The PR description claims "New unit test added" — however, **no unit tests exist for the new [shiftSplit](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/controller/v1/CorrugatorFeedbackController.java:117:2-141:3) controller method**. The dev checklist states tests were added (15/06/2026), but no test case covers:
- Success (200)
- Corrugator not found (404)
- Setup run not found (404)
- Invalid state (409)
- Invalid setup number (`@Min` violation)

This is the most significant gap. Unit tests should be added for the new controller method.

---

**N-002 — `@PathVariable` Missing `value` Attribute in Shift-Split Endpoint**

In `@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/controller/v1/CorrugatorFeedbackController.java:133`:

```@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/controller/v1/CorrugatorFeedbackController.java:133
          @PathVariable @Min(value = 1, message = "corrugatorNumber must be greater than 0") Integer corrugatorNumber,
```

The existing endpoints (lines 74, 104) use `@PathVariable("corrugatorNumber")` with explicit name. The new endpoint at line 133 uses `@PathVariable` without a name. While Spring can resolve this by parameter name when compiled with debug info, best practice (and consistency with other endpoints) is to always specify the name explicitly: `@PathVariable("corrugatorNumber")`.

---

**N-003 — [ShiftSplitRequest](cci:2://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/v1/ShiftSplitRequest.java:12:0-37:1) Lacks `@Min` Validation on `setupNumber`**

In `@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/v1/ShiftSplitRequest.java:15-17`:

```@/home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/v1/ShiftSplitRequest.java:15-17
    @NotNull
    @Schema(description = "Setup number of the setup run to shift-split", example = "30")
    private Integer setupNumber;
```

`setupNumber = 0` or a negative value will pass the `@NotNull` check and be sent to the service, which will attempt a DB query. A `@Min(1)` or `@Positive` constraint should be added to fail fast at the validation layer, consistent with how `corrugatorNumber` is validated at the path-variable level.

---

**N-004 — Missing `@Valid` or `@Validated` on [ShiftSplitRequest](cci:2://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/v1/ShiftSplitRequest.java:12:0-37:1) for Nested Validation**

Related to N-003: even if `@Min` is added to [ShiftSplitRequest](cci:2://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/v1/ShiftSplitRequest.java:12:0-37:1), the `@Valid` annotation on the `@RequestBody` in the controller (line 134) is needed to trigger bean validation. This is already present (`@Valid @RequestBody ShiftSplitRequest request`), so nested field constraints _will_ be applied. ✅ This is fine — mentioned as a note to confirm.

---

**N-005 — [CscFeedbackStateException](cci:2://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/exception/CscFeedbackStateException.java:9:0-21:1) Is Used for Two Semantically Different Errors**

[CscFeedbackStateException](cci:2://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/exception/CscFeedbackStateException.java:9:0-21:1) is thrown for both:
1. Invalid setup state (`NOT_PROC_SHIFT`) — a business state error
2. `shiftSplitTime` in the future (`SHIFT_SPLIT_TIME_IN_FUTURE`) — an input validation error

These should semantically map to different HTTP codes: the state error → 409, the time validation → 400 (bad request). Currently both map to 409 in the handler. The future-time error is more naturally a `400 Bad Request` since it is a client input issue, not a conflicting resource state. **Consider throwing `IllegalArgumentException` for the time validation error** (which is already handled as 400 in the exception handler at line 393).

---

## Section 5 — Acceptance Criteria Verification

| AC | Status | Evidence |
|---|---|---|
| POST endpoint correctly created | ✅ | `CorrugatorFeedbackController.java:130–142` |
| Delegates to `cscService.shiftSplitSetup()` with correct arguments | ✅ | `CorrugatorFeedbackService.java:263–272`, matches comms handler signature |
| Returns `newSetupNumber` and `newProgramNumber` | ✅ | [ShiftSplitResponse.java](cci:7://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/dto/v1/ShiftSplitResponse.java:0:0-0:0), populated from `pair.getCurrentFeedback()` |
| 409 for invalid state | ✅ | Lines 237–242, mapped to 409 in exception handler |
| 409/400 for future split time | ⚠️ | Lines 254–259 — mapped to 409 but arguably should be 400 (N-005) |
| 404 for corrugator not found | ✅ | [CorrugatorNotFoundException](cci:2://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/exception/CorrugatorNotFoundException.java:8:0-17:1) → 404 |
| 404 for setup not found | ✅ | [SetupRunNotFoundException](cci:2://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/exception/SetupRunNotFoundException.java:8:0-17:1) → 404 |
| No AC formally written on work item | ⚠️ | Achu Vasudevan requested AC — not yet added |

---

## Section 6 — Gaps

| ID | Description |
|---|---|
| G-001 | No formal acceptance criteria on ADO #977196 — review based on derived AC from resolution notes |
| G-002 | KB search returned no shift-split-specific TDD/spec documents |

---

## Section 7 — Summary Verdict

The implementation is **functionally sound** and correctly mirrors the existing comms handler behavior. The core shift-split flow, exception hierarchy, and HTTP status mapping are well-structured. However, there are **blocking gaps** before merge:

**Must fix before merging:**
1. **M-001** — Wrap `XmgenCscServiceException` in `CscServiceException` instead of bare `RuntimeException` to avoid unhandled 500s with no error body.
2. **N-001** — Add unit tests for the [shiftSplit](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/controller/v1/CorrugatorFeedbackController.java:117:2-141:3) controller endpoint (success, 404, 409 paths).

**Recommend fixing:**
3. **M-003** — Narrow `SHIFT_SPLIT_STATUS_FILTER` to avoid fetching setups that will immediately be rejected.
4. **N-005** — Map `SHIFT_SPLIT_TIME_IN_FUTURE` to 400 (Bad Request) instead of 409.
5. **C-001** — Remove the redundant `/feedback/shift-split` matcher from the auth configurator.
6. **N-002** — Add explicit `value` to `@PathVariable`.
7. **N-003** — Add `@Min(1)` or `@Positive` on `ShiftSplitRequest.setupNumber`.

**Low priority:**
8. **M-002** — Add a comment in [parseShiftSplitTime](cci:1://file:///home/logesh.mk@kiwiplan.co.nz/projects/PR_Review/KP-MapJava/csc/kp-csc/kp-csc-service/src/com/kiwiplan/csc/rest/service/CorrugatorFeedbackService.java:655:2-658:3) explaining the `ZoneId.systemDefault()` contract.
9. **M-004** — Use `Time.now()` consistently instead of `new Time()`.
10. **C-002** — Document or consolidate the two-step corrugator lookup.