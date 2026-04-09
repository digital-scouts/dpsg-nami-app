---
description: "Use when: working on the Node.js statistics server under server/, its Docker setup, or server-specific CI. Keeps the server isolated from Flutter code and root project logic."
applyTo: ["server/**", ".github/workflows/server-*.yml"]
---

# Server Isolation

- Keep implementation, scripts, configuration, and tests inside `server/` unless a root-level workflow or shared documentation file must be updated deliberately.
- Do not import, execute, or depend on Flutter source, Dart tooling, or files under `lib/`, `test/`, `tool/`, `android/`, or `ios/`.
- Server CI must run with `working-directory: server` and use only Node.js and server-local commands.
- Prefer `docker-compose` and MongoDB for server development instead of host-installed database tooling.
