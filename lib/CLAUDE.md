# Flutter-App (lib/)

Gilt zusaetzlich zu den Root-Regeln in [../CLAUDE.md](../CLAUDE.md). Die Isolationsregeln betreffen auch test/, tool/, android/ und ios/.

## Isolation

- Keine Importe aus server/, keine Ausfuehrung von Server-Skripten, keine Dateisystem-Kopplung zu Server-Internals.
- Integriere mit dem Server nur ueber explizite API-Vertraege, DTOs oder dokumentierte HTTP-Schnittstellen.

## UI und Design

- Bewahre bestehende UI- und Architekturentscheidungen, statt Bereiche ohne Anlass umzugestalten.
- Aendere Storybook-Stories unter lib/stories und den Storybook-Einstieg in lib/main_storybook.dart, wenn Komponenten oder wichtige Zustaende abgesichert werden muessen.
- Wenn Design-Artefakte, Prototypen oder Screen-Vorgaben aus Open Design relevant sind, nutze den angebundenen Open-Design-MCP-Server als primaere externe Quelle fuer Designkontext.
- Behandle Artefakte mit Namen wie `*-android` als globale Vorgaben fuer alle Devices, sofern nicht ausdruecklich eine plattformspezifische Abweichung dokumentiert ist.

## Befehle

- Dependencies installieren: `flutter pub get`
- Tests ausfuehren: `flutter test`
- Statische Analyse: `flutter analyze`
- Formatierung pruefen: `dart format --output=none --set-exit-if-changed .`
- Formatierung anwenden: `dart format .`
- Versionskonsistenz pruefen: `dart tool/validate_versions.dart`
- Env-Konsistenz pruefen: `dart tool/validate_env_files.dart`
