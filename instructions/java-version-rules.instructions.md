---
applyTo: '**/*.java'
---

# Java Version Rules

## General Rule

Do not assume all repositories use the same Java version. Check the repository, `pom.xml`, build files, Maven compiler settings, toolchains, or existing code before using version-specific features.

## Java 11 Repositories

Known Java 11 repositories:

- `KP-MapJava`
- `KP-Tool-JavaBuild`
- `KP-Xmit-LinkDeviceSimulator`
- `KP-Xmit-VLink-2.0`

For Java 11 projects, strictly avoid Java features introduced after Java 11.

Do not use:

- records
- modern switch expressions
- pattern matching
- text blocks
- sealed classes
- virtual threads
- sequenced collections
- newer Java APIs unavailable in Java 11

Prefer Java 11-compatible syntax and APIs.

## Java 25 Repositories

Known Java 25 repositories:

- `KP-Xmit-LinkCentral`
- `KP-Xmit-LinkDevice`
- `KP-Xmit-LinkSimulator`

For Java 25 projects, stay conservative for readability.

Use newer Java features only when:

- they fit the existing project style
- they improve clarity
- they do not make the code harder for the team to maintain
- the user explicitly asks for modernization

## Java Version Switching

Use SDKMAN when switching Java versions:

```bash
sdk use java 11.0.19-amzn
sdk use java 17.0.19-amzn
sdk use java 25.0.3-amzn
```
