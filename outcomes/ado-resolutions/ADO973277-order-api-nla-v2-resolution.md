# Fundamentals

**Background:**
Review and enhance the existing `kp-pcs-service` v1 order APIs to ensure they meet NLA (Next Level Automation) requirements. A new v2 REST API was introduced that exposes order/job/step data with additional NLA scheduling fields (`startTime`, `runSpeed`, `targetRunSpeed`) not available in v1.

The following v2 endpoints were created:
- `GET /api/v2/orders/{orderNumber}/jobs/{jobNumber}/steps` — all steps for a job
- `GET /api/v2/orders/{orderNumber}/jobs/{jobNumber}/steps/{stepNumber}` — single step

The JINI-layer `OrderJobStepDTO` was extended with the three new scheduling fields, and the `OrderJobStepMapper` (JINI impl) was updated to populate them from `lineupEntry` data. Security configuration was updated to allow unauthenticated access to the new v2 endpoints, consistent with existing NLA endpoint patterns.

**Programs:**
KP-MapJava (kp-pcs-service / kp-pcs)

**PR Link:**
[PR #42600 — Implement NLA v2 Order/Job/Step API with mapping and controller](https://dev.azure.com/advantive-devops/Advantive/_git/KP-MapJava/pullrequest/42600)

**Branch:**
`feature/ado-973277-order-api` → `main`

# Files Changed

| **File** | **Change Type** | **Description** |
| --- | --- | --- |
| `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/mapper/v2/OrderJobStepMapperV2.java` | Add | New v2 mapper — converts JINI `OrderJobStepDTO` to `OrderJobStepJsonDTOV2`, including null-safe ProgressStatus enum bridging |
| `pcs/kp-pcs-service-api/src/com/kiwiplan/pcs/service/model/v2/OrderJobStepJsonDTOV2.java` | Add | New v2 response DTO — extends v1 shape with NLA scheduling fields: `startTime`, `runSpeed`, `targetRunSpeed` |
| `pcs/kp-pcs-service/src/main/java/com/kiwiplan/pcs/rest/controller/OrderControllerV2.java` | Add | New v2 REST controller exposing two Order/Job/Step endpoints, wrapping `LineupService` with v2 response shape |
| `pcs/kp-pcs-service/src/main/java/com/kiwiplan/pcs/rest/config/auth/PcsAuthenticationPatternConfigurator.java` | Edit | Added v2 endpoint patterns to the unauthenticated access list |
| `pcs/kp-pcs-service/src/main/java/com/kiwiplan/pcs/rest/config/WebSecurityConfig.java` | Edit | Added v2 endpoint path matchers to bypass authentication, matching existing NLA open-access pattern |
| `pcs/kp-pcs-service/src/test/java/com/kiwiplan/pcs/rest/controller/TestOrderControllerV2.java` | Add | Unit tests for `OrderControllerV2` — covers single step, all steps, empty/null responses, and error handling |
| `pcs/kp-pcs/kp-pcs-impl/src/kiwiplan/pcs/mappers/OrderJobStepMapper.java` | Edit | Populates new scheduling fields (`startTime`, `runSpeed`, `targetRunSpeed`) from `lineupEntry`, guarded by null checks |
| `pcs/kp-pcs/kp-pcs-impl/testsrc/kiwiplan/pcs/mappers/TestOrderJobStepMapper.java` | Edit | Added test covering new scheduling fields mapping from `LineupEntry` |
| `pcs/kp-pcs/kp-pcs-api/src/kiwiplan/pcs/model/lineups/OrderJobStepDTO.java` | Edit | Extended with `startTime` (Date), `runSpeed` (long), `targetRunSpeed` (long) fields plus getters/setters |
| `pcs/kp-pcs-service/src/test/java/com/kiwiplan/pcs/rest/model/mapper/v2/TestOrderJobStepMapperV2.java` | Add | Unit tests for `OrderJobStepMapperV2` — covers field mapping, null input, list mapping, and ProgressStatus bridging |

# Customer Setup

**Existing**
NA

**New**
No new configuration required. The new v2 REST endpoints are available without additional setup:
- `GET /api/v2/orders/{orderNumber}/jobs/{jobNumber}/steps`
- `GET /api/v2/orders/{orderNumber}/jobs/{jobNumber}/steps/{stepNumber}`

Both endpoints are unauthenticated (matching existing NLA endpoint access patterns).

**Third-Party Setup**
NA


| **Dev check list** | **Yes/No** | **By whom** | **Date (dd/mm/yyyy)** |
| --- | --- | --- | --- |
| 1. Dev's own test passed | Yes | Laks Yalamati | 27/05/2026 |
| 2. Unit test all passed | Yes | Laks Yalamati | 27/05/2026 |
| 3. New unit test added | Yes | Laks Yalamati | 27/05/2026 |
| 4. Code review passed | Yes | Peter Wang | 27/05/2026 |
| 5. QA preview passed | Yes | Laks Yalamati | 27/05/2026 |
| 6. Solution discussed with TL | NA | NA | NA |
| 7. Solution discussed with architecture team | NA | NA | NA |
| 8. Solution discussed with PO | NA | NA | NA |
| 9. Solution discussed within team | NA | NA | NA |
| 10. No new vulnerability | NA | NA | NA |
| 11. Regression all passed (optional) | NA | NA | NA |


| **QA check list** | **Yes/No** | **By whom** | **Date (dd/mm/yyyy)** |
| --- | --- | --- | --- |
| 1. Artifacts added in Azure Test Plans? |   |   |   |
| 2. Evidence of test runs (screenshots/logs added)? |   |   |   |
| 3. Any bugs identified? |   |   |   |
| 4. QA meet the AC/DOD? |   |   |   |
