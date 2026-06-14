# Fundamentals

**Background:**
LinkCentral bundle was missing sample configuration files, making it harder for customers to set up and configure the application. This technical task adds sample configuration files to the LinkCentral bundle so customers have reference configurations available out of the box.

The deploy script has been updated to:
- Copy resources from `src/main/resources/` into the bundle
- Create a `config/` directory for actual runtime configurations
- Include sample configs in a `sample/` directory for customer reference

Start and stop scripts have also been renamed and moved to keep LinkCentral consistent with LinkDevice conventions (`link-central-start.sh` / `link-central-stop.sh`).

Logback configuration was inlined into `logback-spring.xml` (removing the dependency on the external `kiwiconf/kiwiplan/linkcentral.logback.xml` include file), and a dedicated error log appender was added.

**Programs:**
LinkCentral (KP-Xmit-LinkCentral)

**PR Link:**
[PR #42428 - Build file update to include samples](https://dev.azure.com/advantive-devops/0e254f90-a87c-479e-abde-680deb67b476/_git/f4953e8a-d6b4-42c3-a750-905c4eb32337/pullrequest/42428)

**Branch:** `feature/ado-974347-include-sample-config` → `main`

---

# Files Changed

| File | Change |
|---|---|
| `deploy/deploy.sh` | Overhauled: now copies `src/main/resources/*` into bundle, creates `config/` dir, removes `springdoc.properties` |
| `deploy/README.MD` | Updated reference from `kiwiplan/linkcentral.yaml` to `config/linkcentral.yaml` |
| `src/main/resources/link-central-start.sh` | Renamed from `deploy/linkcentral/kp-start-link.sh`; updated config path from `./kiwiplan/` to `./config/` |
| `src/main/resources/link-central-stop.sh` | Renamed/moved from `deploy/linkcentral/kp-stop-link.sh` |
| `src/main/resources/logback-spring.xml` | Inlined logback config (removed external include); added dedicated error log appender |
| `deploy/linkcentral/kiwiplan/linkcentral.yaml` | **Deleted** (symlink removed) |
| `deploy/linkcentral/kiwiplan/linkcentral.logback.xml` | **Deleted** (symlink removed) |
| `deploy/linkcentral/kp-status-link.sh` | **Deleted** |
| `kiwiconf/kiwiplan/linkcentral.yaml` | **Deleted** (moved to sample config) |
| `kiwiconf/kiwiplan/linkcentral.logback.xml` | **Deleted** (inlined into logback-spring.xml) |
| `kiwiconf/kiwiplan/machinepollconfig.yaml` | **Deleted** (moved to sample config) |
| `src/main/resources/linkcentral.yaml` | **Deleted** (consolidated) |

---

# Customer Setup

**Existing**
NA

**New**
New LinkCentral bundle file structure and script naming introduced:

```
linkcentral/
├── linkcentral.jar
├── link-central-start.sh          ← replaces kp-start-link.sh
├── link-central-stop.sh           ← replaces kp-stop-link.sh
├── config/                        ← actual runtime configs go here
│   └── linkcentral.yaml
└── sample/                        ← reference sample configs for customers
    └── linkcentral.yaml
    └── linkcentral.yaml-<customer-variant>
    └── ...
```

Config location updated in start script:
```bash
# Before
--spring.config.location=./kiwiplan/
# After
--spring.config.location=./config/
```

**QA Note:**
From now, the new start and stop scripts for LinkCentral are:
- `link-central-start.sh`
- `link-central-stop.sh`

The `config/` folder is used for actual runtime configs and `sample/` is for all sample/reference configs.

**Third-Party Setup**
NA

---

| **Dev check list** | **Yes/No** | **By whom** | **Date (dd/mm/yyyy)** |
| --- | --- | --- | --- |
| 1. Dev's own test passed | Yes | Laks Yalamati | 26/05/2026 |
| 2. Unit test all passed | NA | NA | NA |
| 3. New unit test added | NA | NA | NA |
| 4. Code review passed | Yes | Peter Wang | 26/05/2026 |
| 5. QA preview passed | Yes | Laks Yalamati | 26/05/2026 |
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
