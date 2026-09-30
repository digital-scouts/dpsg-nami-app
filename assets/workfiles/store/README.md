# Store-Einträge

Store-Grafiken und -Texte für Google Play und den App Store. Alles ist bewusst als erweiterbarer Arbeitsstand gedacht.

## Ablauf

1. Rohscreens aus den Storybook-Szenen `Store/...` (`lib/stories/store/`) erzeugen:
   `tool/store_screenshots/run_store_screenshots.sh --device <iPhone-Pro-Max-UDID> --name iphone`
   `tool/store_screenshots/run_store_screenshots.sh --device <iPad-Pro-13-UDID> --name ipad`
2. `preview.html` im Browser öffnen: Stil wählen, Slides und Texte prüfen.
3. Texte, Headlines und Reihenfolge in `content.js` anpassen.
4. Exportieren: `./render.sh navy|hell|stufen` (benötigt Google Chrome). Ergebnis in `out/`.

## Neue Szene ergänzen

Story in `lib/stories/store/store_scenes_story.dart` anlegen und in `storeSceneStories()` eintragen, Rohscreens neu erzeugen und in `content.js` als Slide mit `scene: '<name>'` aufnehmen. Die Beispieldaten stehen in `lib/stories/store/store_showcase_data.dart`.
