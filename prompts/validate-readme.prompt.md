---
name: validate-readme
description: Validate the README file for completeness and accuracy
agent: spec-validator
tools: [read, agent, edit, search]
---

Given the README.md file in the root of the repository, validate that it contains accurate and complete information about the project.
Consider the spec, if present, along with any recent changes to the codebase.
Suggest edits to the README to ensure it reflects the current state of the project.