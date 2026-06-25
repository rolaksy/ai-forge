---
applyTo: '**/*.{js,jsx,ts,tsx,css,scss,html}'
---

# React Frontend Instructions

## React Repositories

Known repositories with React frontend code:

- `KP-Xmit-LinkDevice`
- `KP-Xmit-LinkSimulator`
- `KP-Xmit-VLink-2.0`

## React Style

- Use functional components and hooks.
- Use 2-space indentation for JavaScript, TypeScript, JSX, and React files.
- Keep components small, reusable, and testable.
- Prefer feature-based folder organization.
- Avoid god components.
- Keep state local unless shared state is clearly needed.
- Avoid unnecessary abstractions and premature generalization.

## Frontend Build Context

Some React frontends are integrated through Maven using the frontend Maven plugin. Respect the existing build flow and package manager configuration.

## Testing

- Use Jest and React Testing Library where applicable.
- Avoid snapshot testing unless there is a clear reason.
- Prefer behavior-focused tests over implementation-detail tests.
- Update tests when behavior changes.

## Security

- Validate user inputs where appropriate.
- Avoid unsafe DOM manipulation.
- Do not expose secrets or sensitive configuration in frontend code.
- For Electron/preload code, use secure IPC messaging and avoid direct insecure DOM access.
