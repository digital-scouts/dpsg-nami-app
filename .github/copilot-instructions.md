# Projektleitlinien

## Architektur

- Bevorzuge kleine, fokussierte Aenderungen, die zur bestehenden Struktur unter lib/domain, lib/data, lib/presentation und lib/services passen.
- Behebe Probleme an der Ursache statt mit oberflaechlichen Workarounds.
- Verwende in deutschsprachigen Markdown-Fliesstexten echte Umlaute und ß. Technische Literale wie Code, Pfade, Dateinamen, URLs, Env-Keys, CLI-Beispiele, Identifier und API-Felder bleiben ASCII.
- Halte bestehende Benennungen, Dateistruktur und Muster konsistent, sofern die Aufgabe keinen abweichenden Eingriff erfordert.

## Flutter und UI

- Bewahre bestehende UI- und Architekturentscheidungen, statt Bereiche ohne Anlass umzugestalten.
- Aendere Storybook-Stories unter lib/stories und den Storybook-Einstieg in lib/main_storybook.dart, wenn Komponenten oder wichtige Zustaende abgesichert werden muessen.

## Tests und Validierung

- Fuehre nach relevanten Aenderungen passende Tests aus, bevorzugt gezielt fuer den betroffenen Bereich.
- Wenn Verhalten geaendert wird, ergaenze oder aktualisiere Tests im test-Verzeichnis.
- Behandle Storybook als Teil der UI-Absicherung und nicht als losgeloeste Demo.

## Versionierung und Release

- Aendere Release-Dateien nur bewusst und konsistent.
- Halte pubspec.yaml, assets/changelog.json und docs/version.json inhaltlich stimmig, wenn eine Release-Aufgabe dies erfordert.
- Nutze vorhandene Validierung wie tool/validate_versions.dart, wenn Versions- oder Release-Dateien betroffen sind.
- Wenn Env-Keys geaendert werden, halte .env.example, lokale .env, ios/ci_scripts/ci_pre_xcodebuild.sh, GitHub-Workflow-Env-Erzeugung und tool/validate_env_files.dart synchron.

## Dokumentation

- Halte README, docs und specs synchron zum tatsaechlichen Verhalten der App.
- Aktualisiere Dokumentation nur dort, wo sich Verhalten, Bedienung, Setup oder Release-Ablauf wirklich geaendert hat.

## Arbeitsweise

- Lies zuerst die relevanten Dateien, bevor du groessere Aenderungen vornimmst.
- Vermeide unnoetige Massenreformatierung und unangrenzende Refactorings.
- Benenne Annahmen, Risiken oder offene Punkte knapp, wenn sie fuer die Aufgabe relevant bleiben.
