---
applyTo: '**'
---

# Troubleshooting and Debugging Instructions

## Troubleshooting Style

- Start from the observed error, logs, stack trace, failing command, or failing test.
- Identify the likely root cause before suggesting broad changes.
- Prefer minimal diagnostic steps.
- Do not guess when repository files, logs, or configuration can confirm the issue.

## Debugging Output

When explaining a defect or troubleshooting result, include:

- issue summary
- likely root cause
- evidence from logs/code/configuration
- recommended fix
- validation steps
- risk or side effects

## Commands

When suggesting commands:

- use commands that match the repository and Java version
- prefer targeted Maven module commands for large multi-module repos
- include the working directory when helpful
- avoid destructive commands unless clearly explained

## Common Focus Areas

Check for:

- Java version mismatch
- Maven dependency conflicts
- parent POM/dependency management issues
- cyclic dependencies
- classpath conflicts
- environment variables
- database version/configuration mismatch
- frontend build integration issues
- Selenium/Appium timing and selector instability

## Issue / Bug Report Format

When creating a bug or issue summary, include:

```md
## Issue Title

<short title>

## Issue Summary

<concise summary>

## Issue Details

### Screen

<screen/module/page if applicable>

### Problem

<what is wrong>

## Observed Behavior

<actual behavior>

## Expected Behavior

<expected behavior>

## Steps to Reproduce

1. <step>
2. <step>
3. <step>
```
