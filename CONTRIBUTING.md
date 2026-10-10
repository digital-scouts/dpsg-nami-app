# Mitwirken

Dieses Dokument richtet sich an alle, die an der App oder am Statistikserver mitentwickeln. Was die App kann und wie sie sich verhält, steht auf [GitHub Pages](https://digital-scouts.github.io/dpsg-nami-app/) (Quelle unter [docs/](docs/)).

## Aufbau

- Flutter-App: `lib/`, `test/`, `integration_test/`, `tool/`, `android/`, `ios/`
- Statistikserver (Node): `server/`, siehe [server/README.md](server/README.md)
- GitHub Pages (Jekyll, Theme just-the-docs): `docs/`
- Konzepte und Analysen: `specs/`

App und Server sind bewusst voneinander isoliert und importieren nichts voneinander.

## Einrichten

```sh
flutter pub get
cp .env.example .env   # Werte für Hitobito, Wiredash, Geoapify, MapTiler eintragen
flutter run
```

Ohne Hitobito-Zugang lässt sich die App über „Demo ansehen“ auf dem Anmeldebildschirm ausprobieren.

## Hitobito OAuth

Für die Entwicklung gegen die Demo-Instanz verwendet die App eine reduzierte Hitobito-Konfiguration über `.env` mit `HITOBITO_BASE_URL`, Client-ID, Client-Secret und Redirect-URI. Authorization-, Token-, Discovery-, Profil- und People-Endpunkte werden daraus im Code abgeleitet. Client-ID und Client-Secret können zusätzlich in den Entwickler-Werkzeugen (nur Debug- und Profile-Builds, unter Hilfe & Diagnose) zur Laufzeit testweise überschrieben werden; im Release gilt immer die `.env`, ein gespeicherter Override wird ignoriert; die Werte werden lokal sicher gespeichert und erst nach erfolgreicher Prüfung übernommen.
Neue Env-Keys müssen immer auch in [.env.example](.env.example) enthalten sein, weil lokale Validierung, GitHub Actions und Xcode Cloud dieses Template als Referenz verwenden.

## Supporter-Käufe

Design-Pakete und Förderer-Abo laufen über `in_app_purchase`. Die Store-Anbindung ist nur aktiv, wenn `SUPPORTER_STORE_ENABLED=true` gesetzt ist. Ohne den Schalter gibt es keinen Kaufweg, und gesperrte Optionen bleiben gesperrt. Die Produkt-IDs stehen in [supporter_produkt.dart](lib/domain/supporter/supporter_produkt.dart) und sind in App Store Connect und der Play Console identisch angelegt.

- Ohne Store testen: In Debug- und Profile-Builds simuliert Debug & Tools einen Kauf. Diese Auswahl geht dem Store vor.
- iOS lokal: In Xcode unter Edit Scheme → Run → Options die Datei [ios/Supporter.storekit](ios/Supporter.storekit) als StoreKit-Konfiguration wählen und aus Xcode starten.
- iOS Sandbox: In Xcode Cloud die Variable `SUPPORTER_STORE_ENABLED=true` setzen und in TestFlight mit einem Sandbox-Konto kaufen.
- Android: Die Repository-Variable `SUPPORTER_STORE_ENABLED=true` setzen; der interne Track nutzt sie dann. Gekauft wird mit einem Lizenztester-Konto.

## Versionierung

Die aktuelle App-Version wird zentral in [pubspec.yaml](pubspec.yaml) gepflegt.
Alle anderen Stellen lesen diese Version entweder zur Laufzeit aus oder werden beim Flutter-Build daraus abgeleitet.

Zusätzlich muss die höchste Version in [assets/changelog.json](assets/changelog.json) zur Version aus der pubspec passen.
Beispiel:

```yaml
version: 1.0.0+1
```

Dann muss der höchste Eintrag im Changelog `1.0.0` sein.

Wenn dieselbe Release-Version erneut deployed werden soll, wird nur die Build-Metadaten-Komponente in [pubspec.yaml](pubspec.yaml) erhöht, zum Beispiel von `1.0.0+1` auf `1.0.0+2`.
Der Changelog bleibt dabei auf `1.0.0`, weil nur die Release-Version ohne Build-Metadaten relevant ist.

Für Update-Hinweise in der App pflegt der Betreiber die Versionsangaben im Admin des Statistikservers unter `/admin/versionen` (siehe [server/spec/app_feeds.md](server/spec/app_feeds.md)).
Sie enthalten pro Plattform die zuletzt als verfügbar markierte Version, die minimale unterstützte Version, den Store-Link und optional ein Sicherheitsupdate.
Sie beschreiben bewusst nicht den aktuellen Entwicklungsstand, sondern den tatsächlich freigegebenen Stand pro Plattform; `latest` wird nach der Freigabe im Store von Hand gesetzt.
Die App lädt sie über `APP_UPDATE_URL` aus der `.env` (`/app/version`) und cached die Antwort lokal. Die Fetch-Frequenz und das Timeout werden über `APP_UPDATE_MIN_FETCH_INTERVAL_HOURS` und `APP_UPDATE_FETCH_TIMEOUT_SECONDS` gesteuert.

Die Prüfung kann lokal manuell ausgeführt werden:

```sh
dart tool/validate_versions.dart
```

Für Env-Dateien gibt es zusätzlich eine Konsistenzprüfung gegen [.env.example](.env.example):

```sh
dart tool/validate_env_files.dart
```

## Git Hooks

Im Repository liegt ein lokaler Pre-Commit-Hook unter [.githooks/pre-commit](.githooks/pre-commit).
Damit der Hook verwendet wird, muss das Hook-Verzeichnis einmal pro lokalem Clone aktiviert werden:

```sh
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

Ab dann wird vor jedem Commit automatisch geprüft, ob [pubspec.yaml](pubspec.yaml) und [assets/changelog.json](assets/changelog.json) zueinander passen. Bei einer Abweichung wird der Commit abgebrochen.

Wenn lokal eine [.env](.env) vorhanden ist, prüft der Hook zusätzlich, ob die Keys zu [.env.example](.env.example) passen.

Außerdem bricht der Hook ab, wenn API-Mitschnitte versioniert werden sollen, also Postman-Collections und -Environments, HAR-Dateien, `.xcappdata`-Bundles oder Dateien unter `specs/demoResponse/`. Solche Mitschnitte können echte Personendaten enthalten. Für Tests gibt es synthetische Fixtures. Die Prüfung steckt in [tool/validate_tracked_files.dart](tool/validate_tracked_files.dart).

## GitHub Actions

Die gleiche Versionsprüfung läuft zusätzlich in GitHub Actions:

- [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) validiert Pull Requests nach `develop` und `master` mit Versionscheck, Formatierung, Analyse und Tests.
- [deploy-android-internal.yml](.github/workflows/deploy-android-internal.yml) baut ein Android App Bundle und deployed es nach Pushes auf `develop`, nach gemergten Pull Requests auf `master` oder manuell in den internen Play-Track. Die `.env` entsteht aus [.env.example](.env.example): Wiredash, Geoapify und Hitobito kommen wie in Xcode Cloud nur aus CI (Secrets `PROD_WIREDASH_SECRET`, `PROD_WIREDASH_PROJECT_ID`, `GEOAPIFY_KEY`, `HITOBITO_OAUTH_CLIENT_SECRET`; Variablen `HITOBITO_BASE_URL`, `HITOBITO_OAUTH_CLIENT_ID`, `HITOBITO_OAUTH_REDIRECT_URI`) und erzeugen bei fehlenden Werten eine Warnung. Alle übrigen Keys übernehmen den Default aus `.env.example`; die Repository-Variablen `STATS_SERVER_URL` und `SUPPORTER_STORE_ENABLED` überschreiben ihn optional.
- [server-status.yml](.github/workflows/server-status.yml) prüft täglich Erreichbarkeit, Zertifikat und Backup-Alter des Statistikservers und meldet Probleme als Issue.
- [rotation-erinnerung.yml](.github/workflows/rotation-erinnerung.yml) legt vierteljährlich ein Issue zur Prüfung der Schlüssel-Rotation an, sofern keines offen ist.
- [create-github-release.yml](.github/workflows/create-github-release.yml) erstellt nach gemergten Pull Requests auf `master` oder manuell einen GitHub Release auf Basis der Version aus [pubspec.yaml](pubspec.yaml) und der Eintraege aus [assets/changelog.json](assets/changelog.json).

Die Workflows laufen nur für den Bereich, der sich geändert hat:

- In [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) entscheidet der Job `changes` anhand der geänderten Pfade. Die Flutter-Validierung und `Update check Android` laufen nur bei App-Änderungen (`lib/`, `test/`, `integration_test/`, `assets/`, `android/`, `ios/`, `tool/`, `pubspec.*`, `analysis_options.yaml`, `.env.example`), der macOS-Job nur bei Änderungen an `ios/` oder `pubspec.*`. Übersprungene Pflicht-Checks gelten als bestanden, reine Server- oder Doku-PRs sind also ohne App-Lauf mergebar. PRs, die nur `pubspec.yaml` oder den Changelog ändern, prüfen ausschließlich die Versionskonsistenz. Auch der Versionssprung für `master`-PRs wird nur bei App-Änderungen verlangt.
- [server-validate.yml](.github/workflows/server-validate.yml) und [server-deploy.yml](.github/workflows/server-deploy.yml) laufen nur bei Änderungen unter `server/`.
- Deploy nach Play (ohne `ios/`) und GitHub Release laufen nur, wenn der Merge App-Dateien enthält.
- Ein neuer Push auf einen PR bricht den noch laufenden Validierungslauf ab.

Neue App-Verzeichnisse oder -Dateien müssen in diese Pfadlisten aufgenommen werden.

Der Job `Validate tracked files` in [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) läuft bei jedem PR. Er prüft dieselben Sperrmuster wie der Pre-Commit-Hook, zusätzlich über die gesamte Git-Historie (`dart tool/validate_tracked_files.dart --history`). Damit fällt auch ein Branch auf, der noch auf der Historie vor der Bereinigung vom Oktober 2026 basiert.

Zusätzlich validieren [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) und [deploy-android-internal.yml](.github/workflows/deploy-android-internal.yml) die Env-Vorlage über [tool/validate_env_files.dart](tool/validate_env_files.dart), damit neue oder entfernte Keys nicht unbemerkt an [.env.example](.env.example) vorbeilaufen.

Für PRs enthält [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) jetzt auch eine macOS-Jobstufe, die native iOS-Swift-Quelltexte formatiert und den iOS-Runner mit `xcodebuild` für den Simulator kompiliert.

Android wird in PRs als Release-App-Bundle gebaut und auf 16-KB-Seitenunterstützung geprüft. Der Pflicht-Check `Update check Android` installiert auf einem Emulator die letzte Release-Version (neuester Tag unterhalb der pubspec-Version, aktuell `v0.2.8`) mit Testdaten, aktualisiert darauf auf den PR-Stand und prüft den Start. Anschließend startet er das Release-Bundle so, wie Google Play es ausliefert (siehe [tool/upgrade_test/run_upgrade_test.sh](tool/upgrade_test/run_upgrade_test.sh) und [tool/android/](tool/android/)).

Dadurch kann eine inkonsistente Versionierung nicht unbemerkt in den Hauptbranch gelangen, auch wenn lokal kein Hook aktiviert ist. Der GitHub Release enthält bewusst nur Tag und Release-Notizen, aber kein angehängtes Android-Binärfile.

Der iOS-Release-Pfad läuft weiterhin außerhalb von GitHub Actions über Xcode Cloud beziehungsweise App Store Connect.
Das Xcode-Cloud-Skript [ios/ci_scripts/ci_pre_xcodebuild.sh](ios/ci_scripts/ci_pre_xcodebuild.sh) erzeugt die lokale [.env](.env) dabei anhand der Keys aus [.env.example](.env.example).
Xcode Cloud übernimmt dabei keine Werte aus [.env.example](.env.example), nur die Variablen aus App Store Connect. Wenn Env-Keys oder Default-Werte wie URLs geändert werden, müssen deshalb die Xcode-Cloud-Variablen nachgezogen werden.

Direkte Pushes nach `master` werden als Hotfixes behandelt und lösen bewusst keine Release- oder Deploy-Workflows aus.

## Storybook und Screenshots

Storybook ist Teil der UI-Absicherung.

Zum Starten:

```sh
flutter run -t lib/main_storybook.dart
```

Store- und Handbuch-Screenshots entstehen aus den Storybook-Szenen `Store/...` und `Docs/...` im iOS-Simulator:

```sh
# Store-Rohscreens nach assets/workfiles/store/raw/<sprache>/<name>/
tool/store_screenshots/run_store_screenshots.sh --device <simulator-udid> --name iphone --lang de
# Handbuch-Bilder (600 px, JPEG) nach docs/assets/img/screens/
tool/store_screenshots/run_store_screenshots.sh --set docs --device <iphone-udid>
```

Komposition, Texte (Deutsch und Englisch) und der Upload per Fastlane sind unter [assets/workfiles/store/](assets/workfiles/store/README.md) beschrieben. Den ganzen Durchlauf führt der Claude-Skill `store-seite` (`.claude/skills/store-seite/`).

## Karten-Geodaten

Für die Kartenansicht unter Einstellungen wird zur Laufzeit kein Shapefile geladen, sondern ein leichtgewichtiges GeoJSON-Asset unter [assets/maps/dioeceses.geojson](assets/maps/dioeceses.geojson).

Die Quelldaten stammen aus generalisierten Bistumsgrenzen im Shapefile-Format und werden vorab lokal nach WGS84/EPSG:4326 konvertiert. Das Konvertierungsskript liegt unter [tool/convert_bistum_shapefile.py](tool/convert_bistum_shapefile.py), reduziert den Attributsatz auf die für die App benötigten Felder und kanonisiert die Nutzerbezeichnungen auf stabile fachliche Diözesanverbände. Der Offizialatsbezirk Oldenburg wird dabei fachlich dem Diözesanverband Münster zugeordnet und bereits im GeoJSON zusammengeführt.

Die Vereinfachung bleibt bewusst konfigurierbar. Aktuell ist das eingebundene Karten-Asset mit 85 Prozent Genauigkeit erzeugt, also mit 15 Prozent Vereinfachung:

```sh
python3 -m venv .venv
./.venv/bin/pip install pyshp pyproj
./.venv/bin/python tool/convert_bistum_shapefile.py --simplify-percent 15
```

Stammstandorte lädt die App zur Laufzeit aus der DPSG-Stammessuche und speichert sie zwischen. Solange noch kein Abruf gespeichert ist, nutzt sie das Asset [assets/maps/stamm_markers.json](assets/maps/stamm_markers.json), das `dart run tool/export_stamm_markers.dart` neu erzeugt.

Die aktuell eingebundene Kartenansicht kombiniert generalisierte Bistumsgrenzen als fachliche Näherung für DPSG-Diözesen mit Stammstandorten aus dem Store-Locator-Pfad. Beim Auswählen eines Stammes oder einer Diözese zeigt die Karte den Namen und, sofern gepflegt, einen direkten Website-Link an. Weitere Kartenebenen bauen künftig auf demselben GeoJSON-basierten Laufzeitpfad auf.

## Dokumentation

- [README.md](README.md) stellt das Projekt vor und listet den Funktionsumfang.
- [docs/](docs/) ist die GitHub-Pages-Seite: Funktionsübersicht (`index.html`), Handbuch (`docs/handbuch/`), Technik (`docs/technik/`) und Rechtliches. Lokal ansehen mit `cd docs && bundle exec jekyll serve`.
- [assets/changelog.json](assets/changelog.json) enthält die Neuerungen je Version, die die App anzeigt.

Changelog und `specs/` werden im selben PR wie die Änderung gepflegt. README, CONTRIBUTING und `docs/` zieht der Claude-Skill `doku-abgleich` (`.claude/skills/doku-abgleich/`) gebündelt beim Versionswechsel oder auf Anfrage nach; bis zu welchem Commit das geschehen ist, hält der Skill in `docs/_data/doku_stand.yml` fest.

### Dokumentationsstil

Für deutschsprachige Fließtexte in [README.md](README.md), unter [docs](docs) und unter [specs](specs) gilt UTF-8-Schreibweise mit echten Umlauten und ß.
ASCII bleibt auf technische Literale begrenzt, insbesondere für Code, Dateinamen, Pfade, URLs, Env-Keys, CLI-Beispiele, Identifier und API-Felder.
