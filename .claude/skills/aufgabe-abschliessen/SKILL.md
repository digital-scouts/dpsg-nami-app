---
name: aufgabe-abschliessen
description: Eine Aufgabe abschließen – Vollständigkeit prüfen, Changelog pflegen, lokal validieren, GitHub-Issues und specs/todos.md abgleichen, committen und PR nach develop erstellen. Verwenden, wenn eine Umsetzung fertig ist oder der Nutzer „Aufgabe abschließen“, „fertig machen“, „PR erstellen“ oder „Changelog pflegen“ sagt.
---

# Aufgabe abschließen

Ein Durchlauf bringt eine fertige Umsetzung in einen PR: prüfen, Changelog, validieren, Issues abgleichen, nach einer Freigabe ausführen. README, CONTRIBUTING und `docs/` gehören nicht dazu; sie werden gebündelt beim Versionswechsel gepflegt.

## 0. Bestandsaufnahme

- Branch prüfen: nicht `develop` oder `master`. Sonst einen Branch `feat/…`, `fix/…` oder `chore/…` vorschlagen.
- `git status`, `git diff develop...HEAD` und uncommittete Änderungen lesen. Kurz zusammenfassen, was sich geändert hat und welche Bereiche betroffen sind (App, Server, iOS).
- Fremde Dateien und Reste markieren und fragen, ob sie mitgehen: z. B. `ios/Podfile.lock`, lokale `.env`, `TEMP`-Zeilen, `print`/`debugPrint`, auskommentierter Code.

## 1. Vollständigkeit

Nur für die betroffenen Bereiche:

- **Sichtbare Änderung:** Entscheidung unter `design/entscheidung/` vorhanden, `design/.runden/<thema>/` gelöscht (Skill `feedbackrunde`).
- **Tests:** Bei geändertem Verhalten Tests unter `test/` ergänzt, ohne echte Zeit (Uhr injizieren).
- **Storybook:** Stories unter `lib/stories` sichern neue Komponenten oder wichtige Zustände ab. Handbuch-Szenen und -Bilder gehören zum Doku-Abgleich, nicht hierher.
- **Lokalisierung:** Neue Texte gibt es auf Deutsch und Englisch.
- **specs/:** Specs zum geänderten Verhalten sind aktuell.
- **Env-Keys geändert:** `.env.example`, lokale `.env`, `ios/ci_scripts/ci_pre_xcodebuild.sh` und die Env-Erzeugung in den GitHub-Workflows sind synchron.

Kleine Lücken selbst schließen. Größere nennen und per AskUserQuestion klären.

## 2. Changelog

- Jede nutzerseitig sichtbare Änderung bekommt im selben PR einen kurzen Eintrag in `assets/changelog.json` unter der Version aus `pubspec.yaml` (bis zum Livegang 1.0.0), als `features` oder `bugFixes`, aus Nutzersicht formuliert, ohne Technikdetails. Stil wie die vorhandenen Einträge.
- Vorher nach einem ähnlichen Eintrag suchen und ihn anpassen, statt einen zweiten anzulegen.
- Kein Eintrag für interne Umbauten ohne sichtbare Wirkung, Funktionen hinter einem Schalter (z. B. `SUPPORTER_STORE_ENABLED`) und Store-Texte oder -Bilder. Der Grund kommt als ein Satz in den PR.

## 3. Validierung

**Automatisiert, immer und ohne Rückfrage:**

- App: `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, gezielt `flutter test` (bei breiten Änderungen alle Tests).
- Immer: `dart tool/validate_versions.dart` und `dart tool/validate_tracked_files.dart`.
- Env geändert: `dart tool/validate_env_files.dart`.
- Server betroffen: in `server/` `npm run typecheck` und `npm test`.

Fehler beheben, Ergebnisse für „Geprüft“ im PR festhalten.

**Manuell, optional:** Prüfungen im Simulator oder auf dem Gerät (z. B. Profile-Build für Offline-Fälle) nur als kurze Liste vorschlagen. Der Nutzer entscheidet. Nicht ausgeführte stehen im PR unter „Offen“.

## 4. Issues abgleichen

- `gh issue list --state open --limit 100 --json number,title,labels,body`
- Mit dem Diff abgleichen: Stichworte, Dateien und Bereiche, Verweise in Branchname, Commits, Entscheidungsdatei und `specs/todos.md`.
- Einordnen:
  - **erledigt:** `Closes #N` im PR. PRs gehen nach `develop`, GitHub schließt erst beim Release-Merge nach `master`. Deshalb zusätzlich im Issue kommentieren: „Erledigt mit #PR in develop, wird mit dem Release geschlossen.“
  - **teilweise erledigt:** Checkboxen abhaken (Body direkt vorher neu lesen, nur betroffene Zeilen ändern, `gh issue edit <N> --body-file <datei>`), im Issue kommentieren, was erledigt ist und was offen bleibt. Im PR `Teil von #N`.
  - **nur berührt:** im PR `Bezug: #N`, Issue unverändert.
- Neue offene Punkte (z. B. „Offenes“ der Entscheidungsdatei) als neue Issues vorschlagen: Titel, Checkliste, vorhandenes Label (`gh label list`).
- `specs/todos.md` führt nur offene Aufgaben mit Issue-Verweis: Erledigtes streichen, Teilstände anpassen, neue Issues eintragen.
- Unsichere Zuordnungen als Frage markieren, nicht raten.

## 5. Freigabe

Knapp im Chat:

- **Umsetzung:** zwei bis drei Sätze, was die Änderung bewirkt.
- **Issues:** Tabelle mit Nummer, Titel, Status (erledigt / teilweise mit den Checkboxen / Bezug / neu vorgeschlagen) und geplanter Aktion.
- **Offen:** falls vorhanden.

Commits, Dateien und PR-Text nicht vorab zeigen, sie stehen danach im PR. Dann AskUserQuestion: **PR erstellen**, **anpassen** oder **lokal bleiben** (nur committen).

## 6. Ausführen

- Commits auf Deutsch im Format `Bereich: Beschreibung`, mit der `Co-Authored-By`-Zeile aus der Sitzung.
- `git push -u origin <branch>`
- `gh pr create --base develop`, Titel `Bereich: Beschreibung`. Abschnitte:
  - `## Worum es geht`
  - `## Änderungen`, mit der Changelog-Entscheidung als ein Satz („Kein Changelog-Eintrag: …“)
  - `## Issues` mit `Closes #N`, `Teil von #N`, `Bezug: #N` (entfällt, wenn keine)
  - `## Geprüft`
  - `## Offen` (entfällt, wenn nichts offen ist)
  - am Ende die Generated-with-Claude-Code-Zeile aus der Sitzung
- Danach Issue-Kommentare und Checkboxen ausführen und die freigegebenen neuen Issues anlegen. `specs/todos.md` gehört in den Commit.
- CI nicht abwarten.

## 7. Nachlauf

- Memory pflegen: Projekt-Memories zum Thema aktualisieren (z. B. „nicht gepusht“ → „PR #X offen“), neue Entscheidungen, die nicht im Repo stehen, als Memory anlegen.
- Abschluss im Chat: PR-Link, geänderte Issues, offene Punkte.
- Wurden Screens geändert, die als Store-Szene in `lib/stories/store/` vorkommen, auf den Skill `store-seite` fürs nächste Store-Update hinweisen.
