---
name: store-seite
description: Store-Einträge für App Store und Google Play aktualisieren – Screenshots (iPhone, iPhone Duo, iPad, Play Phone und Tablet, Vorstellungsgrafik, App-Store-Kopfzeile und Suchergebnis) und Texte auf Deutsch und Englisch erzeugen und per Fastlane hochladen. Verwenden bei neuer Version, geänderten Store-Szenen oder neuen Funktionen, oder wenn der Nutzer die Store-Seite, Store-Screenshots oder Store-Texte aktualisieren will.
---

# Store-Seite

Ein Durchlauf bringt Texte und Bilder beider Stores auf den Stand der App: Bestand aufnehmen, Texte und Szenen pflegen, Rohscreens im Simulator erzeugen, komponieren, prüfen, per Fastlane hochladen. Alles Technische steht in `assets/workfiles/store/README.md`; dieser Skill ist die Reihenfolge und die Regeln.

**Einzige Quelle:** `assets/workfiles/store/content.js` (Slides, Texte, Grenzen; je Sprache `de`/`en`). Nichts direkt in App Store Connect oder der Play Console ändern, sonst überschreibt der nächste Upload es.

## 0. Bestand aufnehmen

- Version aus `pubspec.yaml` mit `STORE.version` in `content.js` vergleichen.
- Neue Einträge in `assets/changelog.json` seit der Version des letzten Store-Stands lesen.
- Was hat sich seit den letzten Rohscreens geändert?
  `git log --oneline $(git log -1 --format=%H -- assets/workfiles/store/raw/) -- lib/stories/store/ lib/presentation/`
  Betroffene Szenen zuordnen (Szene → Screen siehe `lib/stories/store/store_scenes_story.dart`).
- Neue oder entfallene Funktionen aus dem Changelog ableiten. `README.md` und `docs/index.html` zieht danach der Skill `doku-abgleich` nach.
- Dem Nutzer kurz zusammenfassen: veraltete Szenen, neue Funktionen, ob eine Feedbackrunde ansteht.

## 1. Feedbackrunde

Pflicht, wenn sich die Version geändert hat oder der Nutzer sie verlangt; sonst überspringen.

- Skill `feedbackrunde` nutzen. Fragen typischerweise: Reihenfolge der Slides, Headlines/Sublines je Slide, Stil (`navy`, `hell`, `stufen`), neue oder entfallende Szenen, Claim für Kopfzeile und Vorstellungsgrafik.
- Als Varianten die echten Exporte zeigen (`out/<lang>/…` nach Schritt 5 oder `screenshot.html?…` im iframe), keine Nachbauten.
- Erst nach der Entscheidung `STORE.version` auf die neue Version setzen. Entscheidung nach `design/entscheidung/`.

## 2. Texte

In `content.js` für **beide Sprachen** pflegen. Die erste Variante je Sprache ist die aktive.

- **Versionshinweise** (`whatsNew`): aus den Features der Version in `assets/changelog.json`, aus Nutzersicht, ohne Technik. Play erlaubt nur 500 Zeichen.
- **Beschreibung:** neue Funktionen im passenden Abschnitt ergänzen, entfallene streichen. Abschnitte `VORAUSSETZUNG` und `HINWEIS` (keine Verbindung zur DPSG) bleiben immer.
- **Nur Vorhandenes nennen.** Supporter-Texte nur, wenn die Store-Anbindung live ist (`SUPPORTER_STORE_ENABLED`, siehe `specs/todos.md` #212).
- **Apple-Bilder** (Kopfzeile, Suchergebnis, Screenshots): keine Preise, URLs oder fremden Plattformen.
- **Keywords:** durch Komma ohne Leerzeichen trennen; Wörter aus Name und Untertitel möglichst nicht wiederholen.
- **Englisch:** Begriffe wie in der englischen App-Übersetzung (`lib/l10n/app_localizations.dart`), z. B. „section change“, „Nationwide comparison“. DPSG-Eigennamen (Meute, Trupp, Runde, Stamm) bleiben.
- Prüfen: `node assets/workfiles/store/export_fastlane.mjs --nur-pruefen` (Grenzen, fehlende Übersetzungen, Keywords).

## 3. Szenen

- Neue Funktion mit eigenem Slide: Story in `lib/stories/store/store_scenes_story.dart` anlegen, in `storeSceneStories()` eintragen, Daten in `store_showcase_data.dart`. Sprache immer über `storeSceneLocale` bzw. `StoreSceneApp`, keine festen deutschen Texte in den Szenen (stattdessen `AppLocalizations`).
- Slide in `content.js` mit `scene: '<dateiname>'` aufnehmen (Dateiname = Story-Name ohne `Store/`, klein, `/` und Leerzeichen → `_`).
- `flutter analyze lib/stories integration_test`.

## 4. Rohscreens

Simulatoren suchen (Namen der Store-Simulatoren):

```sh
xcrun simctl list devices available | grep -E "iPhone 17 Pro Store|iPad Pro 13 Store|iPhone Duo"
```

Fehlt einer, den Nutzer fragen, statt einen anderen Typ zu nehmen (die Auflösung muss stimmen). Dann je Sprache und Gerät, nacheinander (parallele Läufe teilen sich den Build-Ordner):

```sh
tool/store_screenshots/run_store_screenshots.sh --device <iPhone-17-Pro-Store> --name iphone --lang de
tool/store_screenshots/run_store_screenshots.sh --device <iPad-Pro-13-Store> --name ipad --lang de
DEVELOPER_DIR=<Xcode-27.1>/Contents/Developer \
  tool/store_screenshots/run_store_screenshots.sh --device <iPhone-Duo> --name duo --lang de
# dasselbe mit --lang en
```

- Nur veraltete Geräte/Sprachen neu erzeugen, wenn sich nur Texte geändert haben, entfällt der Schritt.
- Duo: Runtime iOS 27.1, aufgeklappt, mit dem iOS-27.1-SDK bauen (Xcode 27.1 per `mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"` finden). Erwartet 2853 × 2007; 2613 × 2007 heißt Kompatibilitätsmodus.
- Der Build braucht eine `.env` im Arbeitsverzeichnis (Asset in `pubspec.yaml`); in einem Worktree aus dem Haupt-Checkout kopieren, nie einchecken.

## 5. Komponieren und selbst prüfen

```sh
assets/workfiles/store/render.sh <stil> alle
```

- Prüft Pixelgröße und Alpha-Kanal jedes Bildes und bricht bei Fehlern ab.
- Stichprobe mit dem Read-Tool ansehen (vorher per `sips --resampleWidth 500 … --out <scratchpad>` verkleinern): je Sprache mindestens ein Bild je Ziel, dazu jede geänderte Szene. Achten auf abgeschnittene oder umbrechende Headlines (Englisch ist oft länger), deutsche Reste in englischen Screens, leere oder halb geladene Szenen.
- Dann `open assets/workfiles/store/preview.html` und den Nutzer prüfen lassen (Sprache und Stil oben umschaltbar, Texte mit Zeichenzähler).

## 6. Hochladen

```sh
node assets/workfiles/store/export_fastlane.mjs
bundle exec fastlane ios store_check
bundle exec fastlane android store_check
```

- `export_fastlane.mjs` schreibt `fastlane/build/` und listet, was von Hand hochzuladen ist.
- `ios store_check` prüft die Screenshot-Formate lokal und ob die Version aus `pubspec.yaml` in App Store Connect bearbeitbar ist. `android store_check` lässt Google Play die Änderungen validieren.
- Fehlt `fastlane/.env`, den Nutzer bitten, sie nach `fastlane/.env.example` anzulegen. Zugangsdaten nie selbst anlegen, ausgeben oder einchecken.
- **Upload nur nach ausdrücklicher Bestätigung** per AskUserQuestion (wirkt nach außen, Live-Einträge ändern sich sofort bzw. mit der nächsten Einreichung):
  - `bundle exec fastlane ios store_upload` – Texte und Screenshots der bearbeitbaren Version, ohne Einreichung.
  - `bundle exec fastlane android store_upload` – Texte und Bilder; Versionshinweise nur mit `changelogs:true`, wenn im Produktions-Track ein Release mit dieser Version liegt.
- Danach die Checkliste für Handarbeit ausgeben:
  - App Store Connect: Kopfzeile `out/<lang>/appstore/header.png`, Suchergebnis `out/<lang>/appstore/search.png`, iPhone-Duo-Screenshots `out/<lang>/duo/` (Formate kennt Fastlane noch nicht). Im Vorschau-Werkzeug den Beschnitt prüfen.
  - Bei geänderter Kaufseite oder neuen Paketen: Prüf-Screenshots `--set review` neu erzeugen und in den In-App-Käufen ersetzen (siehe README).
  - App-Datenschutz, Altersfreigabe und URLs pflegt Fastlane bewusst nicht. Der Name bleibt überall „NaMi“; ihn nur nach Rücksprache ändern.

## 7. Nacharbeiten

- README-Bilder: `for i in 1 2 3 5; do sips -s format jpeg -s formatOptions 85 --resampleWidth 440 assets/workfiles/store/out/de/iphone/iphone-0$i-*.png --out docs/assets/img/store/iphone-$i.jpg; done`
- Danach den Skill `doku-abgleich` ausführen. Er erzeugt die Handbuch-Bilder neu, die die `Store/`-Szenen mitnutzen.
- Versioniert werden `content.js`, `raw/`, geänderte Szenen und ggf. die Entscheidung. `out/` und `fastlane/build/` nicht.
- Store-Texte und -Bilder sind keine App-Änderung: kein Eintrag in `assets/changelog.json`.
