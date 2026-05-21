# Global Engineering Rules

## Purpose
Establish consistent, industry-standard practices for code quality, architecture, testing, documentation, and secure development across all project interactions.

---

## A) Output & Engineering Standards

### 1. Technology Stack
- **Backend**: Java, Spring Boot (managed via parent POM), Maven multi-module architecture
- **Frontend**: React (functional components + hooks)
- **Architecture**: Domain-Driven Design (DDD) with Clean Architecture principles

---

### 2. Code Structure & Design
- Enforce **layered architecture**: `domain → application/service → adapter/infrastructure`
- Avoid cyclic dependencies (strictly enforced, especially in `com.kiwiplan.linkcentral.comms.core`)
- Organize code by **feature/module**, not technical layers
- Keep classes and components:
  - Small and focused (Single Responsibility Principle)
  - Reusable and testable
- Avoid “god classes/components”

---

### 3. Naming Conventions
- Use **meaningful, intention-revealing names**
- Follow standards:
  - Classes: `PascalCase`
  - Methods/variables: `camelCase`
  - Constants: `UPPER_SNAKE_CASE`
- Align naming with domain language (ubiquitous language in DDD)

---

### 4. Code Quality Practices
- Follow **SOLID, DRY, KISS, YAGNI** principles
- Prefer composition over inheritance
- Handle:
  - Null values
  - Edge cases
  - Timeouts and retries (where applicable)
- Add Javadoc or inline comments only for **non-obvious logic**

---

### 5. Formatting Standards
- Java: 4 spaces indentation
- JavaScript/React: 2 spaces indentation
- Max line length: ~120 characters
- Use consistent formatting tools (Prettier, Checkstyle, or equivalent)
- Always format before committing

---

## B) Testing & Quality Assurance

### 1. Backend Testing
- Use **JUnit 5**
- Coverage requirements:
  - ≥80% line coverage
  - ≥70% branch coverage
- Write meaningful tests focusing on behavior, not implementation

### 2. Frontend Testing
- Use **Jest + React Testing Library**
- Prefer behavior-driven tests
- Avoid excessive snapshot testing

### 3. Testing Principles
- Unit tests:
  - Avoid unnecessary mocking
  - Do not mock core business logic
- Integration tests:
  - Prefer real components over mocks
- Never alter test intent to pass tests

---

## C) Documentation Standards

- Every feature/change must include documentation:
  - `README.md` updates OR
  - Entry in `/docs`
- Document:
  - Setup instructions
  - Usage
  - Assumptions and limitations
- Maintain research and supporting docs in:
  - `/docs/research`
- Use:
  - Clear headings
  - Code blocks with file paths
  - Concise explanations

---

## D) Security & Compliance

- Never expose secrets (code, logs, configs)
- Validate all inputs (frontend + backend)
- Follow secure coding practices:
  - Input sanitization
  - Output encoding
  - Proper authentication/authorization

### Electron-Specific
- Use secure IPC communication
- Avoid direct DOM manipulation from preload scripts
- Enforce context isolation

---

## E) Workflow & Tooling Guidelines

### 1. Command Execution
- Use `filesystem.run-command` for all terminal operations

### 2. Azure DevOps (ADO)
- Use **ado-mcp** for all ADO interactions
- Best practices:
  - Fetch work items in batches
  - Use `get_work_items_batch_by_ids`
  - Display only: **ID, Type, Title, State**
  - Never perform update/delete operations
  - Present results in markdown tables

### 3. Java Version Management
Use SDKMAN commands:
- `sdk use java 11.0.28-ms`
- `sdk use java 17.0.17-ms`
- `sdk use java 25-ms`

---

## F) Refactoring & Change Management

- Do not introduce new functionality unless explicitly required
- Seek approval before major refactoring
- Ensure:
  - Backward compatibility
  - Tests pass after changes

---

## G) Visualization Standards

- Use **Mermaid diagrams** for architecture
- Use **SVG diagrams** for non-architecture visuals

---

## H) Output Formatting

- Use proper Markdown formatting
- Wrap:
  - Code blocks
  - Commands
  - File paths
- When multiple code snippets are provided:
  - Clearly label each with purpose and file path

---

## I) Engineering Principles Summary

- Build maintainable, scalable, and secure systems
- Prioritize readability over cleverness
- Optimize for long-term sustainability
- Ensure consistency across teams and modules

---

**End of Document**
