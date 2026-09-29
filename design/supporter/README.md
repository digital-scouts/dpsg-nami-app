# Supporter-Designs

Quellen für App-Icons, Supporter-Badges, animierte Hintergründe und Farbpaletten. Alle Dateien werden aus Code erzeugt, damit Varianten einheitlich bleiben und sich gezielt nachschärfen lassen.

```sh
node design/supporter/build_ios_icons.mjs   # iOS-Icons (Icon Composer), ca. 2 Minuten
node design/supporter/export_app_assets.mjs # Badges, Vorschaubilder, Android- und iOS-Icons in die App
node design/supporter/generate.mjs          # Entwürfe und preview.html
open design/supporter/preview.html
```

`export_app_assets.mjs` schreibt nach `assets/supporter/`, `android/app/src/main/res/` und `ios/Runner/*.icon`. Neue Icon-Namen müssen zusätzlich in `AndroidManifest.xml` (activity-alias), `AppIconChannel.java`, `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` im Xcode-Projekt und `lib/domain/appearance/appearance_catalog.dart` nachgezogen werden. `design/supporter/ios/` ist ein Zwischenstand und nicht versioniert.

`build_ios_icons.mjs` braucht Google Chrome (Rastern der Ebenen) und Xcode 26 oder neuer (`ictool` aus Icon Composer für die Kontrollbilder).

- `lib/icons.mjs`: 4 Szenen × 3 Tageszeiten (`icons/<motiv>-<zeit>.svg`, 1024 × 1024), jeweils in drei Ebenen teilbar
- `build_ios_icons.mjs`: Icon-Composer-Bundles für iOS 26/27 mit Liquid Glass; `*Automatisch.icon` zeigt hell den Morgen und dunkel die Nacht
- `lib/badges.mjs`: Kompass in 6 Farben plus Förderer-Badge Polarstern (`badges/*.svg`)
- Hintergründe: 3 Szenen, jeweils Tag (hell) und Nacht (dunkel). Freigegeben sind die Entwürfe aus `lib/entwurf_lagerfeuer_nacht.mjs` und `lib/entwurf_szenen.mjs` (Zuordnung in `generate.mjs`, `FINAL_BACKGROUNDS`); `lib/backgrounds.mjs` liefert die gemeinsamen Bausteine. Die App zeichnet die Szenen nach in `lib/presentation/widgets/supporter_background_painter.dart`.
- `entwurf-*.html`: Vorschauseiten der Feedback-Runden (ganze Szene, Handy-Kopf ohne und mit Suche) (`backgrounds/*.svg`)
- `lib/palettes.mjs`: 5 Paletten mit denselben Tokens wie `DPSGColors` (`palettes.json`)
- `preview.html`: Übersicht mit Auswahl; die Auswahl lässt sich als Liste kopieren

Gestaltungsregel: nur eigene Motive, keine Lilie, keine Stufenlogos und keine DPSG-Designs. Stufenfarben werden nur als Farbwerte verwendet.
