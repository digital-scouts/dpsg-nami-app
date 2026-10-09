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

- Aendere Version in pubspec.yaml und docs/version.json nur bei Release-Aufgaben und konsistent; validiere mit `dart tool/validate_versions.dart`.
- Changelog-Eintraege und Env-Abgleich prueft der Skill `aufgabe-abschliessen` vor jedem PR.

## Dokumentation

- Halte README, docs und specs synchron zum tatsaechlichen Verhalten der App. Aendert sich Verhalten oder Bedienung eines Bereichs, pflege die zugehoerige Seite im selben PR mit.
- Aktualisiere Dokumentation nur dort, wo sich Verhalten, Bedienung, Setup oder Release-Ablauf wirklich geaendert hat.
- README.md stellt das Projekt vor (Funktionsumfang, Store-Bilder, Links). Passe sie nur an, wenn eine Funktion neu dazukommt oder entfaellt. Entwickler-Setup, CI und Release-Ablauf stehen in CONTRIBUTING.md.
- docs/ ist die GitHub-Pages-Seite (Jekyll, just-the-docs, gebaut aus develop:/docs). Texte knapp und auf den Punkt, Anleitungen als nummerierte Schritte mit Screenshots. Zuordnung Bereich → Seite:
  - Funktionsumfang, Werbetexte → docs/index.html (nur bei neuen oder entfallenen Funktionen)
  - Anmeldung, Demo, Offline → docs/handbuch/erste-schritte.md und docs/technik/anmeldung-und-offline.md
  - Arbeitskontext, Rechte → docs/handbuch/arbeitskontext.md, docs/handbuch/faq.md und docs/technik/arbeitskontext.md
  - Stufenwechsel → docs/handbuch/stufenwechsel.md
  - Statistik und Bundesvergleich → docs/handbuch/statistik.md und docs/handbuch/bundesvergleich.md
  - Qualifikationen → docs/handbuch/qualifikationen.md
  - Bearbeiten, Retry, Konflikte → docs/handbuch/aenderungen.md und docs/technik/zusammenfuehrung.md
  - Supporter-Paket → docs/handbuch/supporter.md
  - Hilfe & Diagnose, Feedback → docs/handbuch/probleme-melden.md
  - Neue oder geaenderte externe Dienste, Datenfluesse, Speicherfristen → docs/technik/externe-dienste.md, docs/handbuch/datenschutz.md und die Datenschutzerklaerung docs/app-privacy-policy.md
  - Wiredash-Ereignisse → docs/technik/wiredash.md
- Aendert sich eine Oberflaeche, die im Handbuch abgebildet ist, passe die Szene unter lib/stories/docs/ an und erzeuge die Bilder neu (Befehl in lib/CLAUDE.md).
- Die Adressen /app-privacy-policy, /notifications.json und /version.json ruft die App direkt ab; sie duerfen sich nicht aendern. Verschobene Seiten bekommen ein `redirect_from`.
- Pruefe Aenderungen an docs/ lokal mit `cd docs && bundle exec jekyll build`.

## Arbeitsweise

- Lies zuerst die relevanten Dateien, bevor du groessere Aenderungen vornimmst.
- Vermeide unnoetige Massenreformatierung und unangrenzende Refactorings.
- Benenne Annahmen, Risiken oder offene Punkte knapp, wenn sie fuer die Aufgabe relevant bleiben.
- Sichtbare Aenderungen vor der Umsetzung mit dem Skill `feedbackrunde` (.claude/skills/feedbackrunde/) klaeren. Im Repo landet nur die Entscheidung unter design/entscheidung/, keine Rundendateien.
- Schliesse Aufgaben mit dem Skill `aufgabe-abschliessen` (.claude/skills/aufgabe-abschliessen/) ab: Vollstaendigkeit, Changelog, Validierung, Issues und PR.
