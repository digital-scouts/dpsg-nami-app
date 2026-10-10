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

- Aendere die Version in pubspec.yaml nur bei Release-Aufgaben und konsistent; validiere mit `dart tool/validate_versions.dart`. `latest` je Plattform setzt der Betreiber nach der Store-Freigabe im Admin unter /admin/versionen.
- Changelog-Eintraege und Env-Abgleich prueft der Skill `aufgabe-abschliessen` vor jedem PR.
- Bei einem Versionswechsel erst den Skill `store-seite`, dann `doku-abgleich` ausfuehren.

## Dokumentation

- Halte specs synchron zum tatsaechlichen Verhalten der App und pflege sie im selben PR mit.
- README.md, CONTRIBUTING.md und docs/ pflegt der Skill `doku-abgleich` (.claude/skills/doku-abgleich/) beim Versionswechsel oder auf Anfrage; normale Umsetzungen aendern sie nicht.
- Die Adressen /app-privacy-policy (GitHub Pages) sowie /app/notifications und /app/version (namiapp.scout-link.de) ruft die App direkt ab; sie duerfen sich nicht aendern.

## Arbeitsweise

- Lies zuerst die relevanten Dateien, bevor du groessere Aenderungen vornimmst.
- Vermeide unnoetige Massenreformatierung und unangrenzende Refactorings.
- Benenne Annahmen, Risiken oder offene Punkte knapp, wenn sie fuer die Aufgabe relevant bleiben.
- Subagents nur fuer breite Suchen ueber unbekannte Bereiche starten; bekannte Dateien direkt lesen.
- Bilder (PNG/JPG) nie in Originalgroesse lesen, sondern vorher verkleinern (`sips --resampleWidth 800 <bild> --out <scratchpad>/<bild>`), und dasselbe Bild nicht mehrfach lesen. Jedes gelesene Bild bleibt bis zum Sitzungsende im Kontext.
- Sichtbare Aenderungen vor der Umsetzung mit dem Skill `feedbackrunde` (.claude/skills/feedbackrunde/) klaeren. Im Repo landet nur die Entscheidung unter design/entscheidung/, keine Rundendateien.
- Schliesse Aufgaben mit dem Skill `aufgabe-abschliessen` (.claude/skills/aufgabe-abschliessen/) ab: Vollstaendigkeit, Changelog, Validierung, Issues und PR.
