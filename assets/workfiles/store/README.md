# Store-Einträge

Store-Grafiken und -Texte für Google Play und den App Store, auf Deutsch und Englisch. Den ganzen Ablauf mit Regeln für Texte und Prüfung führt der Claude-Skill `store-seite` (`.claude/skills/store-seite/`).

## Ablauf

1. Rohscreens aus den Storybook-Szenen `Store/...` (`lib/stories/store/`) je Sprache erzeugen:
   `tool/store_screenshots/run_store_screenshots.sh --device <iPhone-17-Pro-UDID> --name iphone --lang de`
   `tool/store_screenshots/run_store_screenshots.sh --device <iPhone-Duo-UDID> --name duo --lang de`
   `tool/store_screenshots/run_store_screenshots.sh --device <iPad-Pro-13-UDID> --name ipad --lang de`
   Dasselbe mit `--lang en`. Ergebnis in `raw/<sprache>/<gerät>/`. Der iPhone-Duo-Simulator braucht die Runtime iOS 27.1 und muss aufgeklappt sein. Gebaut werden muss mit dem iOS-27.1-SDK (`DEVELOPER_DIR=<Xcode-27.1>/Contents/Developer` vor den Befehl), sonst läuft die App im Kompatibilitätsmodus und füllt nur 2613 × 2007 statt 2853 × 2007.
2. `preview.html` im Browser öffnen: Sprache und Stil wählen, Slides und Texte prüfen.
3. Texte, Headlines und Reihenfolge in `content.js` anpassen (je Sprache unter `de`/`en`; die erste Variante ist die aktive). `node export_fastlane.mjs --nur-pruefen` prüft Zeichengrenzen und fehlende Übersetzungen.
4. Exportieren: `./render.sh navy|hell|stufen [de|en|alle]` (benötigt Google Chrome). Ergebnis in `out/<sprache>/`, nummeriert in Store-Reihenfolge (`iphone-01-mitglieder.png`). Ohne `raw/<sprache>/duo/` entfallen nur die Duo-Screenshots.
5. Hochladen per Fastlane, siehe unten.
6. Für die README verkleinerte Kopien ablegen: `for i in 1 2 3 5; do sips -s format jpeg -s formatOptions 85 --resampleWidth 440 out/de/iphone/iphone-0$i-*.png --out ../../../docs/assets/img/store/iphone-$i.jpg; done` (`out/` ist nicht versioniert).

## Formate

| Ziel | Datei | Größe | Upload |
| --- | --- | --- | --- |
| App Store Kopfzeile | `out/<sprache>/appstore/header.png` | 3840 × 1646 | von Hand |
| App Store Suchergebnis | `out/<sprache>/appstore/search.png` | 3840 × 2560 | von Hand |
| iPhone mit Dynamic Island 6,3" | `out/<sprache>/iphone/` | 1206 × 2622 | Fastlane |
| iPhone Duo aufgeklappt | `out/<sprache>/duo/` | 2853 × 2007 | von Hand |
| iPad 13" | `out/<sprache>/ipad/` | 2064 × 2752 | Fastlane |
| Google Play Telefon | `out/<sprache>/play/` | 1080 × 1920 | Fastlane |
| Google Play Tablet | `out/<sprache>/playtablet/` | 1600 × 2560 | Fastlane |
| Google Play Vorstellungsgrafik | `out/<sprache>/play/feature-graphic.png` | 1024 × 500 | Fastlane |

Kopfzeile und Suchergebnis werden je nach Gerät beschnitten: Marke und Text stehen deshalb mittig. Vor dem Veröffentlichen im Vorschau-Werkzeug von App Store Connect prüfen. Die Play-Bilder zeigen die App als Karte ohne Apple-Gerät, Telefon aus den iPhone-, Tablet aus den iPad-Rohscreens. App-Vorschauen (Videos) gibt es noch nicht.

## Fastlane

Fastlane lädt Texte und Screenshots hoch, aber keine Builds und reicht nichts zur Prüfung ein. Den App-Namen setzt es fest auf „NaMi“, weil jede neue Store-Sprache einen braucht; URLs, App-Datenschutz und Altersfreigabe pflegt es bewusst nicht.

Einmalig einrichten:

1. `bundle install` im Repo-Root.
2. `fastlane/.env.example` nach `fastlane/.env` kopieren und eintragen:
   - `APP_STORE_CONNECT_API_KEY_PATH`: JSON-Datei mit `key_id`, `issuer_id` und `key` eines App-Store-Connect-API-Keys (Rolle App-Manager).
   - `SUPPLY_JSON_KEY`: JSON-Datei des Google-Play-Dienstkontos (dasselbe wie das GitHub-Secret `ANDROID_SERVICE_ACCOUNT_JSON`).

   Beide Dateien liegen außerhalb des Repos.

Je Durchlauf:

```sh
node assets/workfiles/store/export_fastlane.mjs   # out/ + content.js -> fastlane/build/
bundle exec fastlane ios store_check               # Formate lokal, Version in App Store Connect
bundle exec fastlane android store_check           # Google Play validiert, ohne zu veröffentlichen
bundle exec fastlane ios store_upload
bundle exec fastlane android store_upload          # changelogs:true für Versionshinweise
```

- `ios store_upload` schreibt in die bearbeitbare Version aus `pubspec.yaml`; sie muss in App Store Connect angelegt sein.
- Die Versionshinweise für Play (`changelogs/default.txt`) gehen nur mit `changelogs:true` hoch und brauchen ein Release im Produktions-Track.
- Kopfzeile, Suchergebnis und Duo-Screenshots kennt Fastlane noch nicht; `export_fastlane.mjs` listet sie am Ende zum Hochladen von Hand.

## Neue Szene ergänzen

Story in `lib/stories/store/store_scenes_story.dart` anlegen und in `storeSceneStories()` eintragen, Rohscreens neu erzeugen und in `content.js` als Slide mit `scene: '<name>'` aufnehmen. Die Sprache kommt über `storeSceneLocale`; feste deutsche Texte in Szenen vermeiden. Die Beispieldaten stehen in `lib/stories/store/store_showcase_data.dart`.

## Prüfinformationen für In-App-Käufe

`tool/store_screenshots/run_store_screenshots.sh --set review --device <iPhone-Pro-Max-UDID>` erzeugt aus den Szenen `Review/...` (`lib/stories/store/review_scenes_story.dart`) je Produkt einen englischen Screenshot nach `review/`: Kaufseite für das Förderer-Abo, Paket-Sheet für jedes Design-Paket. `abo-polarstern-1024.png` ist das Abo-Bild (1024 × 1024, ohne Transparenz). Prüfer erreichen die Käufe ohne Login über die Demo im Zugang „Supporter extras“, der nur mit `SUPPORTER_STORE_ENABLED=true` erscheint.
