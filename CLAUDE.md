# Projektleitlinien

## Architektur

- Bevorzuge kleine, fokussierte Aenderungen, die zur bestehenden Struktur passen.
- Behebe Probleme an der Ursache statt mit oberflaechlichen Workarounds.
- Verwende in deutschsprachigen Markdown-Fliesstexten echte Umlaute und ß. Technische Literale wie Code, Pfade, Dateinamen, URLs, Env-Keys, CLI-Beispiele, Identifier und API-Felder bleiben ASCII.
- Halte bestehende Benennungen, Dateistruktur und Muster konsistent, sofern die Aufgabe keinen abweichenden Eingriff erfordert.

## Struktur und Isolation

- Das Projekt besteht aus der Flutter-App (lib/, test/, tool/, android/, ios/) und dem Node-Statistikserver (server/); beide sind bewusst voneinander isoliert und duerfen nicht gegenseitig importieren oder Dateisystem-Kopplungen eingehen.
- Bereichsspezifische Regeln und Befehle stehen in [lib/CLAUDE.md](lib/CLAUDE.md) fuer die Flutter-App, [server/CLAUDE.md](server/CLAUDE.md) fuer den Statistikserver und [ios/CLAUDE.md](ios/CLAUDE.md) fuer Swift/Xcode.

## Tests und Validierung

- Fuehre nach relevanten Aenderungen passende Tests aus, bevorzugt gezielt fuer den betroffenen Bereich; konkrete Befehle stehen in der jeweiligen bereichsspezifischen CLAUDE.md.
- Wenn Verhalten geaendert wird, ergaenze oder aktualisiere Tests im test-Verzeichnis.
- Behandle Storybook als Teil der UI-Absicherung und nicht als losgeloeste Demo.

## Versionierung und Release

- Aendere Release-Dateien nur bewusst und konsistent.
- Halte pubspec.yaml, assets/changelog.json und docs/version.json inhaltlich stimmig, wenn eine Release-Aufgabe dies erfordert; validiere mit `dart tool/validate_versions.dart`.
- Wenn Env-Keys geaendert werden, halte .env.example, lokale .env, ios/ci_scripts/ci_pre_xcodebuild.sh und die GitHub-Workflow-Env-Erzeugung synchron; validiere mit `dart tool/validate_env_files.dart`.

## Dokumentation

- Halte README, docs und specs synchron zum tatsaechlichen Verhalten der App.
- Aktualisiere Dokumentation nur dort, wo sich Verhalten, Bedienung, Setup oder Release-Ablauf wirklich geaendert hat.

## Arbeitsweise

- Lies zuerst die relevanten Dateien, bevor du groessere Aenderungen vornimmst.
- Vermeide unnoetige Massenreformatierung und unangrenzende Refactorings.
- Benenne Annahmen, Risiken oder offene Punkte knapp, wenn sie fuer die Aufgabe relevant bleiben.
