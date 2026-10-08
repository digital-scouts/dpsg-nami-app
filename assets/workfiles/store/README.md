# Store-Einträge

Store-Grafiken und -Texte für Google Play und den App Store. Alles ist bewusst als erweiterbarer Arbeitsstand gedacht.

## Ablauf

1. Rohscreens aus den Storybook-Szenen `Store/...` (`lib/stories/store/`) erzeugen:
   `tool/store_screenshots/run_store_screenshots.sh --device <iPhone-Pro-Max-UDID> --name iphone`
   `tool/store_screenshots/run_store_screenshots.sh --device <iPad-Pro-13-UDID> --name ipad`
2. `preview.html` im Browser öffnen: Stil wählen, Slides und Texte prüfen.
3. Texte, Headlines und Reihenfolge in `content.js` anpassen.
4. Exportieren: `./render.sh navy|hell|stufen` (benötigt Google Chrome). Ergebnis in `out/`.
5. Für die README verkleinerte Kopien ablegen: `for i in 1 2 3 5; do sips -s format jpeg -s formatOptions 85 --resampleWidth 440 out/iphone/$i.png --out ../../../docs/assets/img/store/iphone-$i.jpg; done` (`out/` ist nicht versioniert).

## Neue Szene ergänzen

Story in `lib/stories/store/store_scenes_story.dart` anlegen und in `storeSceneStories()` eintragen, Rohscreens neu erzeugen und in `content.js` als Slide mit `scene: '<name>'` aufnehmen. Die Beispieldaten stehen in `lib/stories/store/store_showcase_data.dart`.

## Prüfinformationen für In-App-Käufe

`tool/store_screenshots/run_store_screenshots.sh --set review --device <iPhone-Pro-Max-UDID>` erzeugt aus den Szenen `Review/...` (`lib/stories/store/review_scenes_story.dart`) je Produkt einen englischen Screenshot nach `review/`: Kaufseite für das Förderer-Abo, Paket-Sheet für jedes Design-Paket. `abo-polarstern-1024.png` ist das Abo-Bild (1024 × 1024, ohne Transparenz). Prüfer erreichen die Käufe ohne Login über die Demo im Zugang „Supporter extras“, der nur mit `SUPPORTER_STORE_ENABLED=true` erscheint.
