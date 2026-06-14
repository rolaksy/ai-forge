---
name: my-test
description: "Run a full Maven build and test verification for the current project and report results. Use when: user asks to verify the build, run tests locally, check if code compiles, or wants a build health check before creating a PR."
argument-hint: "[maven-module] (e.g. linkcentral-comms)"
user-invocable: true
context: fork
---

# Maven Build Check

Run a full Maven `clean verify` for the current project and report build status, test results, and any errors in a structured summary.

## Resources

- [build-check.sh](./build-check.sh) — shell script that runs `mvn clean verify`, captures output, and writes a structured result summary

## Prerequisites

- Java 17 must be active. Switch with: `ktsdk use java 17.0.19-amzn`
- A `pom.xml` must exist at the project root or the specified module path.

## Steps

### Step 1 — Locate the project root

Check for a `pom.xml` in the workspace root. If the user provides a module name via `argument-hint`, resolve the path relative to the workspace root.

If no `pom.xml` is found anywhere, stop and report the error clearly.

### Step 2 — Switch to Java 17

Run in the terminal:

```bash
ktsdk use java 17.0.19-amzn
```

### Step 3 — Run the build script

Execute [build-check.sh](./build-check.sh) from the project root. The script accepts optional Maven arguments (e.g. `-pl module-name -am`).

```bash
bash ~/.copilot/skills/maven-build-check/build-check.sh [maven-args]
```

The script:
1. Runs `mvn clean verify [maven-args]`
2. Captures stdout/stderr
3. Exits with code `0` on success, `1` on failure
4. Writes a summary block at the end of output (see format below)

### Step 4 — Parse and report results

Read the terminal output and extract:

| Item | Where to find it |
|---|---|
| Build status | Last line: `BUILD SUCCESS` or `BUILD FAILURE` |
| Tests run / passed / failed / skipped | Lines matching `Tests run:` |
| Compilation errors | Lines containing `ERROR` before `BUILD FAILURE` |
| Test failure details | Lines after `FAILURES:` or `ERRORS:` block |
| Total build time | Line starting `Total time:` |

### Step 5 — Display the summary

Output in this format:

---

## 🔨 Maven Build Report — {project-name}

**Status:** ✅ SUCCESS / ❌ FAILURE  
**Build Time:** {total time}  
**Java:** 17 | **Command:** `mvn clean verify {maven-args}`

### 🧪 Test Results
| Module | Tests Run | Passed | Failed | Skipped |
|---|---|---|---|---|
| {module} | {n} | {n} | {n} | {n} |

### ❌ Failures (if any)
```
{failure output — trimmed to 50 lines per failure}
```

### ⚙️ Compilation Errors (if any)
```
{error lines}
```

---

## Notes

- If the build fails due to missing dependencies, suggest `mvn clean verify -U` to force update snapshots.
- Do not modify any source files — this skill is read-only.
- If Java version is wrong, the script will detect it and report clearly before attempting the build.
