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
- Upgrade-Test letzte Release-Version → aktueller Stand auf Emulator/Simulator: `tool/upgrade_test/run_upgrade_test.sh --platform android|ios --device <id>`. Installiert die App auf dem Gerät neu und löscht dabei deren Daten, deshalb nur auf Test-Geräten ausführen. Die Quellversion ist der neueste Tag `vX.Y.Z` unterhalb der pubspec-Version (überschreibbar per `LEGACY_REF`). Dafür müssen `tool/legacy_fixture/vX_Y_Z/{legacy_seed,main_seed}.dart` und `integration_test/upgrade_from_X_Y_Z_test.dart` existieren. Nach jedem Release beides für die neue Version anlegen und das Seed-Verzeichnis in `analysis_options.yaml` ausschließen. In PRs läuft der Test für Android als Pflicht-Check `Update check Android`.
- Release-Build prüfen: `tool/android/check_16kb_alignment.sh <app.aab>` (16-KB-Seiten) und `BUNDLETOOL_JAR=<jar> tool/android/smoke_start_release.sh --aab <app.aab> --device <id>` (Release-Start ohne Absturz).
- Store-Screenshots: `tool/store_screenshots/run_store_screenshots.sh --device <simulator-udid> --name iphone|ipad` erzeugt Rohscreens der Storybook-Szenen `Store/...` (`lib/stories/store/`) im iOS-Simulator; Komposition, Texte und Export liegen unter `assets/workfiles/store/` (siehe dortige README).
- Handbuch-Screenshots: `tool/store_screenshots/run_store_screenshots.sh --set docs --device <iphone-simulator-udid>` erzeugt die Szenen `Store/...` und `Docs/...` (`lib/stories/docs/`) und legt sie verkleinert unter `docs/assets/img/screens/` ab. Neue Szenen in `docsSceneStories()` eintragen, ohne Knobs.
- Legacy-Fixture für Unit-Tests neu erzeugen: `tool/legacy_fixture/generate_0_2_8_fixture.sh`
