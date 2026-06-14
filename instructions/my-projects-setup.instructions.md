---
applyTo: '**'
---

# My Projects Setup Instructions

## Project Root

All main repositories are located under:

```text
/home/laksyalamat/projects
```

## Primary Work Type

The main work is Java development, with some Spring Boot, Maven multi-module, React frontend, test harness, automation, and troubleshooting work.

Legacy XMGEN Fortran/C work exists but is less common and should be handled cautiously.

## Repository Map

### Spring Boot Applications

- `KP-Xmit-LinkCentral`
- `KP-Xmit-LinkDevice`
- `KP-Xmit-LinkDeviceSimulator`
- `KP-Xmit-LinkSimulator`
- `KP-Xmit-VLink-2.0`

### React Frontend Repositories

- `KP-Xmit-LinkDevice`
- `KP-Xmit-LinkSimulator`
- `KP-Xmit-VLink-2.0`

### Java Libraries / Shared Java Modules

- `KP-Library-Java-KiwiplanSpringSecurityClient`
- `KP-Library-Java-KiwiplanSpringSecurityService`
- `KP-Library-Java-ProtocolDataMapping`
- `KP-MapJava` — mixed Java modules, not a simple plain library

### Maven Plugins / Build Tools

- `KP-Tool-JavaBuild`
- `KP-Tool-MavenPlugin`

### Legacy Repositories

- `KP-MAP` — legacy Fortran and C codebase
- `KP-Xmit-XmitTests` — legacy XMGEN tests

### Knowledge / Internal Tools

- `KP-Xmit-KnowledgeBase`
- `KiwiBase`

## Daily Priority Repositories

Pay special attention to these repositories because they are most important for daily work:

- `KP-Xmit-LinkCentral`
- `KP-Xmit-LinkDevice`
- `KP-Xmit-LinkDeviceSimulator`
- `KP-Xmit-LinkSimulator`
- `KP-MapJava`

## Java Version Awareness

Do not assume one Java version across all repositories.

Known Java versions:

- `KP-MapJava` — Java 11
- `KP-Tool-JavaBuild` — Java 11
- `KP-Xmit-LinkCentral` — Java 25
- `KP-Xmit-LinkDevice` — Java 25 plus React frontend
- `KP-Xmit-LinkDeviceSimulator` — Java 11
- `KP-Xmit-LinkSimulator` — Java 25 plus React frontend
- `KP-Xmit-VLink-2.0` — Java 11

## Java 25 Rule

Even in Java 25 repositories, prefer conservative, readable Java. Do not use modern Java features just because they are available.

Use newer features only when they improve clarity and fit the existing code style.

## Java 11 Rule

In Java 11 repositories, strictly avoid Java features introduced after Java 11.

Do not use records, modern switch expressions, pattern matching, text blocks, virtual threads, sequenced collections, or newer APIs unavailable in Java 11.

## Legacy Code Rule

For `KP-MAP`, avoid large refactoring.

Prefer:

- minimal targeted fixes
- clear explanation of impact
- preservation of existing behavior
- careful testing recommendations

Do not modernize legacy Fortran/C code unless explicitly requested.
