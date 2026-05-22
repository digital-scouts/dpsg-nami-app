---
description: "Use when: working on the Flutter app, Dart code, Flutter tests, or app-specific tooling. Keeps the Flutter app isolated from the server implementation under server/."
applyTo: ["lib/**", "test/**", "tool/**", "android/**", "ios/**"]
---

# Flutter Isolation

- Keep Flutter implementation and tooling independent from the statistics server under `server/`.
- Do not import from `server/`, execute server scripts, or create filesystem coupling to server internals.
- Integrate with the server only through explicit API contracts, DTOs, or documented HTTP interfaces.
- When UI work, flows, screen states, design specs, or prototype artifacts are relevant, use the connected Open Design MCP server as the preferred external design source.
- Treat Open Design artifacts named like `*-android` as global guidance for all device classes unless an explicit device-specific rule says otherwise.
