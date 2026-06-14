# ADO-884141: Gopfert Link Communication Issues - LINKDEVICE

**ADO Work Item:** [884141](https://dev.azure.com/advantive-devops/Advantive/_workitems/edit/884141)

**Background:**
The PS team installed the Gopfert Link at Stora Enso Poland - Ostroleka on 24-25/09/2025. After installation and on-site testing, multiple issues were discovered preventing the Link from properly communicating with the Gopfert controller (machine 1127). The lineup messages were not being sent to the Gopfert GUI, and several data integrity and connection stability issues were identified.

**Customer:** Stora Enso Poland - Ostroleka (Ostrołęka)  
**Case Number:** 01207659  
**Priority:** P2: High  
**Affected Version:** linkdevice_v1.0.0_250902  
**Programs:** Link Device, Link Central

# Issues Resolved

## 1. Database Connection Issue

**Problem:**  
The Link Central application experienced intermittent database connection failures after idle periods (>30 minutes). This was especially problematic when the controller was stopped over weekends and restarted on Monday. The error manifested as:
```
com.mysql.cj.jdbc.exceptions.CommunicationsException: Communications link failure
```

**Root Cause:**  
The database server (or network) closed idle connections, but the Tomcat connection pool handed out stale connections because validation-on-borrow was not enabled/configured. When the connection pool size was exhausted with stale connections, new database operations would fail.

**Resolution:**  
Implemented HikariCP connection pool configuration with proper validation and lifecycle management settings. Added the following configuration to `linkcentral.yaml`:

```yaml
hikari:
  maximum-pool-size: 10
  minimum-idle: 2
  connection-timeout: 30000
  idle-timeout: 600000
  max-lifetime: 1800000
  connection-test-query: SELECT 1
```

**Configuration Details:**
- `maximum-pool-size: 10` - Maximum number of connections in the pool
- `minimum-idle: 2` - Minimum number of idle connections maintained
- `connection-timeout: 30000` - Maximum time (30s) to wait for connection from pool
- `idle-timeout: 600000` - Maximum idle time (10 min) before connection is closed
- `max-lifetime: 1800000` - Maximum lifetime (30 min) of a connection in the pool
- `connection-test-query: SELECT 1` - Query to validate connections before use

**Deployment:**  
Updated linkcentral.tar.gz delivered on 13 Feb 2026

## 2. Manual Job ID Support

**Problem:**  
Link Device did not properly handle manually entered jobs in the Gopfert controller. When operators entered job IDs manually at the controller, the Link would encounter errors processing these jobs.

**Root Cause:**  
The Link Device implementation assumed all jobs originated from Kiwiplan and did not have proper validation or handling for manually entered job identifiers that might not exist in the Kiwiplan database.

**Resolution:**  
Enhanced the job processing logic to:
- Detect and validate manual job entries
- Handle job IDs that don't have corresponding Kiwiplan records
- Gracefully process manual jobs without causing system errors
- Log manual job entries for audit purposes

**Impact:**  
Operators can now manually enter jobs at the controller without disrupting Link Device operations or causing communication failures.

## 3. FDLEN, STLEN (Entry Width and Entry Length) Issue

**Problem:**  
The field dimensions (width and length) sent to the Gopfert controller were incorrectly swapped or ordered, causing confusion and potential production errors. This was particularly problematic when the `rotated_on_machine` flag was set to "Y".

**Root Cause:**  
The dimension mapping logic did not properly account for the rotation status. When `rotated_on_machine` was "Y", the width and length values needed to maintain their order, but the code was unconditionally swapping them based on incorrect Gopfert feedback interpretation.

**Resolution:**  
Updated the dimension mapping logic:
- When `rotated_on_machine` = "Y": Width and Length maintain their original order
- When `rotated_on_machine` = "N": Values are swapped as per Gopfert protocol requirements
- Added validation to ensure dimension values are always positive numbers per protocol specification

**Code Changes:**  
Modified the lineup data transformation in Link Device to conditionally handle dimension ordering based on rotation flag.

**Deployment:**  
Updated jar files delivered to kiwiplansftp on 19 Oct 2025 and 13 Feb 2026

# Customer Setup

**Customer:**  
Stora Enso Poland - Ostroleka (Ostrołęka)

**Machine:**  
Gopfert 1127 (Corrugator Dry-End)

**Protocol:**  
Gopfert BHS Dry-End v4.2.6

**Communication:**
- TCP Server Mode on Port 3001 (Link Device)
- TCP Client connects to Controller Port 23000

**Configuration Files:**
- Link Device: `application.yaml`
- Link Central: `linkcentral.yaml` (updated with HikariCP settings)

**Startup Scripts:**
- Link Central: `kp-start-link.sh` / `kp-stop-link.sh` (Port 8444)
- Link Device: `link-device-start.sh` / `link-device-stop.sh` (Port 8882)

**Third-Party Setup:**  
None required

# Verification & Testing

**Testing Performed:**
1. Database connection stability testing over extended idle periods (overnight/weekend)
2. Manual job entry testing at controller
3. Dimension validation for multiple job scenarios with different rotation flags
4. End-to-end lineup message flow verification
5. TCP communication stability testing

**Test Results:**
- Database connections remain stable after 30+ minute idle periods ✓
- Manual job entries processed without errors ✓
- Width/Length dimensions correctly mapped based on rotation flag ✓
- Lineup messages successfully transmitted to Gopfert controller ✓

# Deliverables

**Updated Artifacts:**
1. linkcentral.tar.gz (13 Feb 2026) - Database connection fix
2. link-device.tar.gz (19 Oct 2025) - FDLEN/STLEN fix and manual job support
3. Updated configuration templates with HikariCP settings

**Deployment Location:**  
kiwiplansftp server: /ADO884141/

**Documentation:**
- Updated configuration guide with HikariCP settings
- Startup/shutdown script usage instructions
- Manual job handling guidelines


  
| **Dev check list**<br> | **Yes/No**<br> | **By whom**<br> | **Date (dd/mm/yyyy)**<br> |
| --- | --- | --- | --- |
| 1. Dev's own test passed<br> | Yes | Laks Yalamati | 19/02/2026 |
| 2. Unit test all passed<br> | Yes | Laks Yalamati | 19/02/2026 |
| 3. New unit test added<br> | Yes | Laks Yalamati | 19/02/2026 |
| 4. Code review passed<br> | Yes | Peter Wang | 13/02/2026 |
| 5. QA preview passed<br> | Yes | Phil Sibley | 13/02/2026 |
| 6. Solution discussed with TL<br> | Yes | Peter Wang | 03/12/2025 |
| 7. Solution discussed with architecture team<br> | NA | NA | NA |
| 8. Solution discussed with PO<br> | NA | NA | NA |
| 9. Solution discussed within team<br> | Yes | Achu Vasudevan | 03/12/2025 |
| 10. No new vulnerability<br> | Yes  | Laks Yalamati  | 19/02/2026  |
| 11. Regression all passed (optional)<br> | Yes  | Phil Sibley  | 13/02/2026  |

  
| **QA check list**<br> | **Yes/No**<br> | **By whom**<br> | **Date (dd/mm/yyyy)**<br> |
| --- | --- | --- | --- |
| 1. Artifacts added in Azure Test Plans?<br> | Yes  | Phil Sibley  | 13/02/2026  |
| 2. Evidence of test runs (screenshots/logs added)?<br> | Yes  | Phil Sibley / Laks Yalamati  | 13/02/2026  |
| 3. Any bugs identified?<br> | No  | Phil Sibley  | 13/02/2026  |
| 4. QA meet the AC/DOD?<br> | Yes  | Phil Sibley  | 13/02/2026  |