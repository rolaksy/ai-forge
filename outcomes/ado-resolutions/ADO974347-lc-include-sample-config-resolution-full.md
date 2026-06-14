## 🚀 Implementation Summary

**Date:** 26 May 2026 | **Author:** Laks Yalamati | **PR:** [PR #42428 — Build file update to include samples](https://dev.azure.com/advantive-devops/Advantive/_git/KP-Xmit-LinkCentral/pullrequest/42428)

### 📋 What Was Implemented

1. Updated `deploy.sh` to copy all resources from `src/main/resources/` into the bundle, so sample configuration files are automatically included in the tar archive without manual placement.
2. Reorganised the bundle directory structure — a `config/` subdirectory is created at bundle time to hold actual runtime configs, while the `sample-config` files delivered from `src/main/resources/` serve as the reference starting point.
3. Renamed and relocated the LinkCentral start/stop scripts (`kp-start-link.sh` → `link-central-start.sh`, `kp-stop-link.sh` → `link-central-stop.sh`) into `src/main/resources/` so they are managed alongside the application and are included in the bundle automatically.
4. Removed stale symbolic-link files and redundant copies from `/deploy/linkcentral/kiwiplan/` and `/kiwiconf/kiwiplan/` that were previously tracked in source control.
5. Updated `deploy/README.MD` to reflect the new config directory path (`config/linkcentral.yaml` instead of `kiwiplan/linkcentral.yaml`).

### 🔨 Changes Made

**File:** `deploy/deploy.sh`  
**Change:** Rewrote the bundle assembly logic — the script now runs from the repository root, creates `deploy/linkcentral/` if needed, validates the JAR was built, copies `src/main/resources/*` (which includes sample configs and start/stop scripts) into the bundle, creates a `config/` directory, and removes the build-only `springdoc.properties` before archiving. A guard clause exits early with an error message if `linkcentral.jar` is missing.

```bash
mkdir -p ./deploy/linkcentral
if [ ! -f "./target/linkcentral.jar" ]; then
    echo "ERROR: linkcentral.jar not found! Build may have failed."
    exit 1
fi

cp --remove-destination ./target/linkcentral.jar ./deploy/linkcentral/
cp --remove-destination -r ./src/main/resources/* ./deploy/linkcentral/

cd deploy/linkcentral
mkdir config
rm springdoc.properties
```

**File:** `src/main/resources/link-central-start.sh` (renamed from `deploy/linkcentral/kp-start-link.sh`)  
**Change:** Script moved into `src/main/resources/` so it is part of the application artifact and bundled automatically.

**File:** `src/main/resources/link-central-stop.sh` (renamed from `deploy/linkcentral/kp-stop-link.sh`)  
**Change:** Same as above — stop script co-located with start script under `src/main/resources/`.

**File:** `src/main/resources/logback-spring.xml`  
**Change:** Minor update to the logging configuration bundled with the application.

### 💡 How It Works

- Previously, sample configuration files lived only in `/kiwiconf/kiwiplan/` and `/deploy/linkcentral/kiwiplan/`, and the deploy script copied them selectively. This meant any new sample file had to be explicitly referenced in `deploy.sh`.
- After this change, `deploy.sh` blindly copies everything under `src/main/resources/` into the bundle. Adding a new sample config is now as simple as placing it in `src/main/resources/sample-config/` — no deploy script changes needed.
- The `config/` directory created at bundle time is the **live** config location customers populate; `sample-config/` inside the bundle serves as the reference/template.
- Start/stop script naming now matches the LinkDevice convention (`link-central-start.sh` / `link-central-stop.sh`) for consistency across services.
- Old symbolic-link files (`deploy/linkcentral/kiwiplan/linkcentral.yaml`, `linkcentral.logback.xml`, etc.) pointed back into `/kiwiconf/`. These have been removed — the canonical copies live in `src/main/resources/` and the deploy script resolves them at build time.

### 📁 Key Files

| File | Change |
|---|---|
| `deploy/deploy.sh` | Rewritten bundle logic: copies from `src/main/resources/`, adds JAR guard, creates `config/` dir |
| `deploy/README.MD` | Updated config path reference from `kiwiplan/linkcentral.yaml` → `config/linkcentral.yaml` |
| `src/main/resources/link-central-start.sh` | Renamed from `deploy/linkcentral/kp-start-link.sh`; now bundled via resources |
| `src/main/resources/link-central-stop.sh` | Renamed from `deploy/linkcentral/kp-stop-link.sh`; now bundled via resources |
| `src/main/resources/logback-spring.xml` | Minor logging config update |
| `deploy/linkcentral/kiwiplan/linkcentral.yaml` | Deleted (was a symlink; real file is now in `src/main/resources/`) |
| `deploy/linkcentral/kiwiplan/linkcentral.logback.xml` | Deleted (was a symlink) |
| `deploy/linkcentral/kp-status-link.sh` | Deleted (superseded; QA/ops use `link-central-start/stop.sh`) |
| `kiwiconf/kiwiplan/linkcentral.yaml` | Deleted (canonical copy moved to `src/main/resources/`) |
| `kiwiconf/kiwiplan/linkcentral.logback.xml` | Deleted (canonical copy moved to `src/main/resources/`) |
| `kiwiconf/kiwiplan/machinepollconfig.yaml` | Deleted (moved to `src/main/resources/`) |
| `src/main/resources/linkcentral.yaml` | Deleted (replaced by sample-config approach under `src/main/resources/sample-config/`) |
