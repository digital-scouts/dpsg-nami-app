---
name: doku-abgleich
description: README, CONTRIBUTING und docs/ (Handbuch, Technik, Startseite, Handbuch-Screenshots) mit dem Code abgleichen und optional einen News-Post schreiben. Verwenden bei einem Versionswechsel in pubspec.yaml, nach dem Skill store-seite oder wenn der Nutzer die Doku oder das Handbuch aktualisieren will.
---

# Doku-Abgleich

Ein Durchlauf bringt README, CONTRIBUTING und `docs/` auf den Stand der App: Änderungen seit dem letzten Abgleich sammeln, Texte und Handbuch-Bilder nachziehen, Jekyll-Build prüfen, News-Post anbieten. Normale PRs fassen diese Dateien nicht an; das gebündelte Nachziehen passiert hier.

**Abgrenzung:**
- `aufgabe-abschliessen` pflegt je PR Changelog, `specs/`, Env, Tests und Storybook und erstellt Commit und PR. Dieser Skill übergibt am Ende dorthin.
- `store-seite` pflegt Store-Texte, Rohscreens, Fastlane und die README-Store-Bilder unter `docs/assets/img/store/`. Beim Versionswechsel läuft er zuerst, danach dieser Skill.
- Hier: README-Text, CONTRIBUTING, `docs/index.html`, Handbuch, Technik, Datenschutz, Szenen unter `lib/stories/docs/`, Bilder unter `docs/assets/img/screens/`, News-Posts, `docs/notifications.json`.

## 0. Basis und Branch

- Merker `docs/_data/doku_stand.yml` lesen (`commit`, `datum`, `version`).
  - `git merge-base --is-ancestor <commit> HEAD` erfolgreich: `<commit>` ist die Basis.
  - Sonst (Rebase, nicht gemergter Branch): Basis ist der erste Commit nach `datum`, `git log --first-parent --since=<datum> --format=%H develop | tail -1`.
  - Fehlt der Merker: Erstlauf ohne Diff. Die Doku vollständig gegen den aktuellen Code prüfen.
- Auf `develop` oder `master` einen Branch `chore/doku-abgleich-JJJJ-MM-TT` vorschlagen. Beim Versionswechsel gern derselbe Branch wie für `store-seite`.

## 1. Änderungen sammeln

- `git log --first-parent --oneline <basis>..HEAD` und `git diff --stat <basis>..HEAD`.
- Neue Einträge in `assets/changelog.json` seit der Basis sind die Liste der nutzersichtbaren Änderungen.
- Entscheidungen unter `design/entscheidung/` seit der Basis lesen; sie beschreiben neue Oberflächen meist genauer als der Diff.
- Ziele zuordnen:

  | Bereich | Seite |
  |---|---|
  | Funktionsumfang, Werbetexte (nur bei neuen oder entfallenen Funktionen) | `README.md` (Funktionsumfang), `docs/index.html` |
  | Entwickler-Setup, CI, Release-Ablauf, Werkzeuge (`tool/`, `.github/workflows/`, `.env.example`, `pubspec.yaml`, `ios/ci_scripts/`, `fastlane/`) | `CONTRIBUTING.md` |
  | Anmeldung, Demo, Offline | `docs/handbuch/erste-schritte.md`, `docs/technik/anmeldung-und-offline.md` |
  | Mitgliederliste, Suche, Filter, eigene Gruppen, Mitgliedsdetails | `docs/handbuch/mitglieder.md` |
  | Arbeitskontext, Rechte | `docs/handbuch/arbeitskontext.md`, `docs/handbuch/faq.md`, `docs/technik/arbeitskontext.md` |
  | Stufenwechsel | `docs/handbuch/stufenwechsel.md` |
  | Statistik und Bundesvergleich | `docs/handbuch/statistik.md`, `docs/handbuch/bundesvergleich.md` |
  | Qualifikationen | `docs/handbuch/qualifikationen.md` |
  | Bearbeiten, Retry, Konflikte | `docs/handbuch/aenderungen.md`, `docs/technik/zusammenfuehrung.md` |
  | Supporter-Paket | `docs/handbuch/supporter.md` |
  | Hilfe & Diagnose, Feedback | `docs/handbuch/probleme-melden.md` |
  | Neue oder geänderte externe Dienste, Datenflüsse, Speicherfristen | `docs/technik/externe-dienste.md`, `docs/handbuch/datenschutz.md`, `docs/app-privacy-policy.md` |
  | Wiredash-Ereignisse | `docs/technik/wiredash.md` |
  | Unterstützte Geräte, Darstellung auf breiten Fenstern (iPad, iPhone Duo, Android) | `docs/handbuch/geraetesupport.md` |

- Der Diff ist nur ein Hinweis. Vor jeder Textänderung das Verhalten im Code nachlesen, auch Schalter wie `SUPPORTER_STORE_ENABLED`: Beschrieben wird nur, was Nutzer wirklich sehen.

## 2. Befundliste

Je Datei kurz: was veraltet ist, was neu hinein muss, welche Bilder betroffen sind. Unklare Fälle (z. B. Handbuch oder FAQ, eigene Seite oder Abschnitt) per AskUserQuestion klären, dann umsetzen.

## 3. Texte

- Nur ändern, wo sich Verhalten, Bedienung, Setup oder Release-Ablauf wirklich geändert hat.
- **README.md** stellt das Projekt vor (Funktionsumfang, Store-Bilder, Links). Nur anpassen, wenn eine Funktion neu dazukommt oder entfällt.
- **CONTRIBUTING.md** enthält Entwickler-Setup, CI und Release-Ablauf.
- **docs/** ist die GitHub-Pages-Seite (Jekyll, just-the-docs, gebaut aus `develop:/docs`). Texte knapp und auf den Punkt, Anleitungen als nummerierte Schritte mit Screenshots (`{% include shots.html items="name:Bildunterschrift|…" %}`). Echte Umlaute und ß, technische Literale bleiben ASCII.
- `/app-privacy-policy`, `/notifications.json` und `/version.json` ruft die App direkt ab, sie dürfen sich nicht ändern. Verschobene Seiten bekommen ein `redirect_from`.
- Ein neues Seitenlayout oder ein Umbau von `docs/index.html` geht vorher durch den Skill `feedbackrunde`. Textpflege braucht keine Runde.

## 4. Handbuch-Screenshots

- Betroffene Szenen bestimmen: geänderte Screens, die in `lib/stories/docs/docs_scenes_story.dart` oder `lib/stories/store/store_scenes_story.dart` vorkommen. Szenen bei Bedarf anpassen. Ein neues Bild bekommt eine Szene in `docsSceneStories()`, ohne Knobs. Der Name ergibt den Dateinamen: `Docs/Statistik/Katalog` → `statistik_katalog.jpg`.
- Simulator suchen, bevorzugt der Store-Simulator:
  ```sh
  xcrun simctl list devices available | grep -E "iPhone 17 Pro"
  tool/store_screenshots/run_store_screenshots.sh --set docs --device <udid>
  ```
  Die Bilder sind immer deutsch (`--lang` gilt nur für `--set store`). Der Build braucht eine `.env` im Arbeitsverzeichnis; in einem Worktree aus dem Haupt-Checkout kopieren, nie einchecken.
- Das Skript löscht alle JPEGs und erzeugt sie neu. Danach `git status docs/assets/img/screens` und jedes geänderte Bild mit Read ansehen. Bilder, die sich nur durch Rauschen geändert haben, nach Rückfrage mit `git checkout` zurücksetzen.
- `.claude/skills/doku-abgleich/bilder_pruefen.sh` gleicht Verweise und Dateien ab. Fehlende Bilder beheben. Verwaiste Bilder einbinden oder ihre `Docs/`-Szene entfernen; eine verwaiste `Store/`-Szene ist unschädlich, weil `--set docs` alle Store-Szenen mit erzeugt.
- Gerätebilder für `docs/handbuch/geraetesupport.md` liegen unter `docs/assets/img/geraete/` (das Skript oben fasst sie nicht an). Sie entstehen aus den Store-Rohscreens, die der Skill `store-seite` erzeugt; nach dessen Lauf neu ableiten:
  ```sh
  R=assets/workfiles/store/raw/de; D=docs/assets/img/geraete
  sips -s format jpeg -s formatOptions 82 --resampleWidth 1200 $R/duo/statistik.png --out $D/duo_statistik.jpg
  sips -s format jpeg -s formatOptions 82 --resampleWidth 900 $R/duo/mitglieder.png --out $D/duo_mitglieder.jpg
  sips -s format jpeg -s formatOptions 70 --resampleWidth 900 $R/duo/karte.png --out $D/duo_karte.jpg
  sips -s format jpeg -s formatOptions 82 --resampleWidth 600 $R/ipad/mitglieder.png --out $D/ipad_mitglieder.jpg
  ```
  Eingebunden werden sie über `{% include geraete.html items="phone:screens/mitglieder:iPhone|duo:geraete/duo_mitglieder:iPhone Duo" %}`.
- Gibt es keinen Simulator, den Schritt überspringen und das in der Übergabe sagen.

## 5. Prüfen

```sh
cd docs && bundle exec jekyll build
```

Fehler und Warnungen zu fehlenden Seiten oder Links beheben. Format, Analyse und Tests (z. B. nach geänderten Szenen) übernimmt `aufgabe-abschliessen`.

## 6. News-Post

- Per AskUserQuestion fragen, ob ein Post entstehen soll, mit Themenvorschlag aus Schritt 1 (z. B. „Neu in 1.1: …“). Nein ist eine normale Antwort.
- Bei Ja einen Entwurf unter `docs/_posts/JJJJ-MM-TT-<slug>.markdown` anlegen:
  - Front Matter wie in `docs/_posts/2026-10-08-neue-nami-neue-app.markdown`: `layout: post`, `title`, `date` mit Zeitzone (`+0200` Sommer, `+0100` Winter).
  - Ton wie dort: Ich-Perspektive, Leser mit „ihr“ angesprochen, nutzernah, ohne Technikdetails.
  - Bilder über `shots.html`, Links ins Handbuch mit `{{ '/handbuch/…/' | relative_url }}`.
  - Den Entwurf im Chat zusammenfassen und abstimmen.
- Danach per AskUserQuestion fragen, ob zusätzlich eine In-App-Mitteilung in `docs/notifications.json` entsteht. Felder siehe `lib/core/notifications/pull_notification.dart`:
  ```json
  {
    "id": "news-JJJJ-MM-TT-<slug>",
    "title": { "de": "…", "en": "…" },
    "body": { "de": "…", "en": "…" },
    "type": "info",
    "created_at": "JJJJ-MM-TTT10:00:00+02:00",
    "external_link": "https://digital-scouts.github.io/dpsg-nami-app/…",
    "platform": "all"
  }
  ```
  `type` ist `info`, `warn` oder `urgent`; für News immer `info`. Die `id` nie wiederverwenden: Die App merkt sich bestätigte IDs, eine wiederverwendete Mitteilung sähen viele nicht. Laut `lib/core/notifications/README.md` wertet die App `external_link` noch nicht aus; den Text so schreiben, dass er ohne Link verständlich ist.

## 7. Merker und Übergabe

- `docs/_data/doku_stand.yml` aktualisieren:
  ```yaml
  commit: <git rev-parse HEAD vor dem Doku-Commit>
  datum: JJJJ-MM-TT
  version: <Version aus pubspec.yaml ohne Build-Metadaten>
  ```
- Kurz im Chat: geänderte Seiten, neue oder aktualisierte Bilder, übersprungene Schritte, offene Punkte.
- Commit und PR übernimmt der Skill `aufgabe-abschliessen`. Kein Changelog-Eintrag, weil sich die App nicht ändert.
