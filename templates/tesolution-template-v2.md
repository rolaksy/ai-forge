# Fundamentals

**Background:**
A test harness is required for testing the feature 702447 (Waste recorded using KNFWASTEA is not showing to justify)
Add Test harness (link device simulator) that covers the protocol messages:
R00 (Current run)
P04P (Production history)
P02 (Download/setup)
P04T (Shift start/end)
R03 / P03 (Queue ask/reply)
Constraint for this feature: The coded waste workflow must use only production history messages (P04P, optionally P04L context). 
      
**Programs:** 
Link Device Simulator and Link Simulator

**Demo Link:** 
[Demo link available here](https://advantiveadmin-my.sharepoint.com/:v:/g/personal/laks_yalamati_advantive_com/Ea9tVMms0vVLtYLPSkkg9J8BI009lo8q5WL4nCXoBaUz8w?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0NvcHkifX0&e=FE3m8Q)

# Customer Setup

**Existing**
NZ

**New**
Configuration that has been introduced
```
# tcp configs
simulator.tcp.mode=server
# tcp server
simulator.tcp.server.port=3001
# tcp client
link.tcp.server.hostname=localhost
link.tcp.server.port=23000

# udp configs
simulator.udp.mode=none

# file based link shared folder
link.sharedFolder=/tmp/link_shared_folder
# Link Simulator hostname/IP address
link.device.host-name=localhost
# Link Simulator machine protected line up size
link.device.protected-region-size=1
# Link Device simulator protocol type
#link.general.protocolconfig.type=wetend
# Link Device simulator protocol name
link.general.protocolconfig.protocolName=bhs_dryend
# Link Device simulator protocol version
link.general.protocolconfig.protocolversion=4.2.6
# Link simulator Rest API URL
link.simulator.urlPath=/api/v1/corrugator/dry-end/
link.simulator.hostName=localhost
link.simulator.port=13579
# Link Device simulator web application config (Don't change)
#spring.main.web-application-type=none
# Link Device simulator ssl trust store file path
trust.store=
# Link Device simulator ssl keystore file path
ssl.keystore=
# Link Device simulator ssl trust store password
trust.store.password=
# Link Device simulator ssl keystore password
ssl.keystore.password=
# Turn off SSL validation
ssl.turn-off-validation=true
# For rest APIs
server.port=13580
server.servlet.context-path=/device-simulator-service

```

**Third-Party Setup**
NA


  
| **Dev check list**<br> | **Yes/No**<br> | **By whom**<br> | **Date (dd/mm/yyyy)**<br> |
| --- | --- | --- | --- |
| 1. Dev's own test passed<br> | Yes | Laks Yalamati | 27 Nov 2025 |
| 2. Unit test all passed<br> | Yes | Laks Yalamati | 27 Nov 2025 |
| 3. New unit test added<br> | Yes | Laks Yalamati | 27 Nov 2025 |
| 4. Code review passed<br> | Yes | Peter Wang | 27 Nov 2025 |
| 5. QA preview passed<br> | Yes | Laks Yalamati | 27 Nov 2025 |
| 6. Solution discussed with TL<br> | Yes | Laks Yalamati | 17 Nov 2025 |
| 7. Solution discussed with architecture team<br> | NA | NA | NA |
| 8. Solution discussed with PO<br> | NA | NA | NA |
| 9. Solution discussed within team<br> | NA | NA | NA |
| 10. No new vulnerability<br> | NA  | NA  | NA  |
| 11. Regression all passed (optional)<br> | NA  | NA  | NA  |

  
| **QA check list**<br> | **Yes/No**<br> | **By whom**<br> | **Date (dd/mm/yyyy)**<br> |
| --- | --- | --- | --- |
| 1. Artifacts added in Azure Test Plans?<br> |   |   |   |
| 2. Evidence of test runs (screenshots/logs added)?<br> |   |   |   |
| 3. Any bugs identified?<br> |   |   |   |
| 4. QA meet the AC/DOD?<br> |   |   |   |