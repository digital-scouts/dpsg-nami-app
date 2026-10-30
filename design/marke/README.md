# Marke

Quellen für Logo und Standard-App-Icon (#285). Alles wird aus Code erzeugt, damit Logo, Icon und die Ebenen für die Startanimation (#279) zusammenpassen.

```sh
node design/marke/generate.mjs          # SVGs nach design/marke/svg/ und preview.html
node design/marke/export_app_icons.mjs  # App-Icon nach iOS, Android und Flutter, ca. 20 s
node design/marke/export_startbild.mjs  # natives Startbild der Startbühne (#279)
open design/marke/preview.html
```

`export_app_icons.mjs` schreibt `ios/Runner/NamiAppIcon.icon` (Icon Composer: Verlauf als Füllung, je Gruppe eine helle und eine dunkle Ebene), unter Android das adaptive Icon (`mipmap-anydpi-v26/ic_launcher*.xml`, `drawable/ic_launcher_verlauf.xml`, `mipmap-*/ic_launcher_foreground.png`, `ic_launcher_monochrome.png`) und die Legacy-Icons `ic_launcher*.png` sowie `assets/icon/icon.png`. Kontrollbilder aller iOS-Darstellungen landen unversioniert in `design/marke/vorschau/`. Gebraucht werden Google Chrome und Xcode 26 oder neuer (`ictool`).

- `export_startbild.mjs` schreibt das native Startbild: unter iOS `LaunchFlaeche.imageset` (Verlauf, hell und dunkel) und `LaunchImage.imageset` (Person ohne Halstuch, 160 pt), unter Android `drawable-*/startbild_person.png` und `values(-night)/startbild_farben.xml`. Flutter zeichnet dieselbe Person in `lib/presentation/widgets/startbuehne_person.dart`; Maße und Farben dort mitziehen.
- `lib/marke.mjs`: Farben, Halstuch, Logo (`logo(modus)`) und App-Icon (`icon(modus)`), jeweils hell und dunkel. Das Logo ist transparent, die vordere Person spart die hinteren per Maske aus. Das Icon ist ein Quadrat ohne Rundung, die Plattform maskiert.
- `svg/`: `logo-*.svg`, `icon-*.svg` und die Ebenen `icon-*-grund.svg` (Personen ohne Tuch), `icon-*-tuch.svg` (Tuch und Zipfel), `icon-*-knoten.svg` (Lederring).
- Entscheidung: `design/entscheidung/2026-10-30-marke-logo-app-icon.md`. Änderungen am Aussehen über den Skill `feedbackrunde`.

Gestaltungsregel: Die Lilie, auch das Original der DPSG, ist erlaubt (laut CI freigegeben). Wölfi, Kobold und Biber kommen nicht in Logo oder Icon.
