# Store-Einträge

Store-Grafiken und -Texte für Google Play und den App Store. Alles ist bewusst als erweiterbarer Arbeitsstand gedacht.

## Ablauf

1. Rohscreens aus den Storybook-Szenen `Store/...` (`lib/stories/store/`) erzeugen:
   `tool/store_screenshots/run_store_screenshots.sh --device <iPhone-17-Pro-UDID> --name iphone`
   `tool/store_screenshots/run_store_screenshots.sh --device <iPhone-Duo-UDID> --name duo`
   `tool/store_screenshots/run_store_screenshots.sh --device <iPad-Pro-13-UDID> --name ipad`
   Der iPhone-Duo-Simulator braucht die Runtime iOS 27.1 und muss aufgeklappt sein. Gebaut werden muss mit dem iOS-27.1-SDK (`DEVELOPER_DIR=<Xcode-27.1>/Contents/Developer` vor den Befehl), sonst läuft die App im Kompatibilitätsmodus und füllt nur 2613 × 2007 statt 2853 × 2007.
2. `preview.html` im Browser öffnen: Stil wählen, Slides und Texte prüfen.
3. Texte, Headlines und Reihenfolge in `content.js` anpassen.
4. Exportieren: `./render.sh navy|hell|stufen` (benötigt Google Chrome). Ergebnis in `out/`, nummeriert in Store-Reihenfolge (`iphone-01-mitglieder.png`). Ohne `raw/duo/` entfallen nur die Duo-Screenshots.
5. Für die README verkleinerte Kopien ablegen: `for i in 1 2 3 5; do sips -s format jpeg -s formatOptions 85 --resampleWidth 440 out/iphone/iphone-0$i-*.png --out ../../../docs/assets/img/store/iphone-$i.jpg; done` (`out/` ist nicht versioniert).

## Formate

| Ziel | Datei | Größe |
| --- | --- | --- |
| App Store Kopfzeile | `out/appstore/header.png` | 3840 × 1646 |
| App Store Suchergebnis | `out/appstore/search.png` | 3840 × 2560 |
| iPhone mit Dynamic Island 6,3" | `out/iphone/` | 1206 × 2622 |
| iPhone Duo aufgeklappt | `out/duo/` | 2853 × 2007 |
| iPad 13" | `out/ipad/` | 2064 × 2752 |
| Google Play | `out/play/` | 1080 × 1920, Vorstellungsgrafik 1024 × 500 |

Kopfzeile und Suchergebnis werden je nach Gerät beschnitten: Marke und Text stehen deshalb mittig. Vor dem Veröffentlichen im Vorschau-Werkzeug von App Store Connect prüfen. App-Vorschauen (Videos) gibt es noch nicht.

## Neue Szene ergänzen

Story in `lib/stories/store/store_scenes_story.dart` anlegen und in `storeSceneStories()` eintragen, Rohscreens neu erzeugen und in `content.js` als Slide mit `scene: '<name>'` aufnehmen. Die Beispieldaten stehen in `lib/stories/store/store_showcase_data.dart`.

## Prüfinformationen für In-App-Käufe

`tool/store_screenshots/run_store_screenshots.sh --set review --device <iPhone-Pro-Max-UDID>` erzeugt aus den Szenen `Review/...` (`lib/stories/store/review_scenes_story.dart`) je Produkt einen englischen Screenshot nach `review/`: Kaufseite für das Förderer-Abo, Paket-Sheet für jedes Design-Paket. `abo-polarstern-1024.png` ist das Abo-Bild (1024 × 1024, ohne Transparenz). Prüfer erreichen die Käufe ohne Login über die Demo im Zugang „Supporter extras“, der nur mit `SUPPORTER_STORE_ENABLED=true` erscheint.
