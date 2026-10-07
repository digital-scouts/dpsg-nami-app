# NaMi

[![Download für iOS](./assets/workfiles/Download_on_the_App_Store_Badge_DE_RGB_blk_092917.svg)](https://apps.apple.com/de/app/nami/id6468066816)
[![Download für Android](./assets/workfiles/GetItOnGooglePlay_Badge_Web_color_German.png)](https://play.google.com/store/apps/details?id=de.jlange.nami.app)

![wakatime](https://wakatime.com/badge/user/f75702c6-6ecd-478f-a765-9c0a07c62d50/project/c30b8bfa-fe60-4da1-9a32-9c86bad66605.svg)
[![Watch](https://img.shields.io/github/watchers/JanneckLange/dpsg-nami-app?label=Watch)](https://github.com/JanneckLange/dpsg-nami-app/subscription)

Master:

[![Release](https://img.shields.io/github/v/release/janneckLange/dpsg-nami-app?display_name=tag&include_prereleases)](https://github.com/JanneckLange/dpsg-nami-app/releases)
[![Commit](https://shields.io/github/last-commit/JanneckLange/dpsg-nami-app/master)](https://github.com/JanneckLange/dpsg-nami-app/commits/master)

Develop:

[![Validate](https://github.com/JanneckLange/dpsg-nami-app/actions/workflows/validate-pull-requests.yml/badge.svg)](https://github.com/JanneckLange/dpsg-nami-app/actions/workflows/validate-pull-requests.yml)
[![Commit](https://shields.io/github/last-commit/JanneckLange/dpsg-nami-app/develop)](https://github.com/JanneckLange/dpsg-nami-app/commits/develop)

NaMi steht für die Namentliche Mitgliedermeldung der Deutschen Pfadfinderschaft Sankt Georg (DPSG). Diese App richtet sich speziell an Leitende der DPSG und ermöglicht den mobilen, offline Zugriff auf Mitgliederdaten. Der fachliche Schwerpunkt liegt weiterhin auf dem Stammesalltag. Für die laufende Hitobito-Ausrichtung wird die App konzeptionell um einen wechselbaren Arbeitskontext erweitert, damit auch Nutzer auf Bezirks-, Diözesan- oder Bundesebene bei Bedarf gezielt in einen anderen Layer wechseln können, ohne dass die App ihren Stammfokus verliert.

Diese App wird privat entwickelt und bereitgestellt. Sie steht in keinem Zusammenhang mit der DPSG und ist (wie alle privaten Projekte) weder von der DPSG autorisiert noch unterstützt. Alle Mitgliedsdaten werden auf eigene Verantwortung verwaltet und sind nicht Teil der offiziellen DPSG-Systeme.

Testversion der App laden: [Android](https://play.google.com/store/apps/details?id=de.jlange.nami.app) oder
[iOS](https://testflight.apple.com/join/YGeELMUq)

## Entwicklung

### Versionierung

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

Für Update-Hinweise in der App gibt es zusätzlich eine manuell gepflegte Remote-Datei unter [docs/version.json](docs/version.json).
Sie enthält pro Plattform die zuletzt als verfügbar markierte Version, die minimale unterstützte Version und den Store-Link.
Diese Datei beschreibt bewusst nicht den aktuellen Entwicklungsstand, sondern den tatsächlich freigegebenen Stand pro Plattform.
Die App lädt diese Datei über `APP_UPDATE_URL` aus der `.env` und cached die Antwort lokal. Die Fetch-Frequenz und das Timeout werden über `APP_UPDATE_MIN_FETCH_INTERVAL_HOURS` und `APP_UPDATE_FETCH_TIMEOUT_SECONDS` gesteuert.

Die Prüfung kann lokal manuell ausgeführt werden:

```sh
dart tool/validate_versions.dart
```

Für Env-Dateien gibt es zusätzlich eine Konsistenzprüfung gegen [.env.example](.env.example):

```sh
dart tool/validate_env_files.dart
```

### Git Hooks

Im Repository liegt ein lokaler Pre-Commit-Hook unter [.githooks/pre-commit](.githooks/pre-commit).
Damit der Hook verwendet wird, muss das Hook-Verzeichnis einmal pro lokalem Clone aktiviert werden:

```sh
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

Ab dann wird vor jedem Commit automatisch geprüft, ob [pubspec.yaml](pubspec.yaml) und [assets/changelog.json](assets/changelog.json) zueinander passen. Bei einer Abweichung wird der Commit abgebrochen.

Wenn lokal eine [.env](.env) vorhanden ist, prüft der Hook zusätzlich, ob die Keys zu [.env.example](.env.example) passen.

Außerdem bricht der Hook ab, wenn API-Mitschnitte versioniert werden sollen, also Postman-Collections und -Environments, HAR-Dateien, `.xcappdata`-Bundles oder Dateien unter `specs/demoResponse/`. Solche Mitschnitte können echte Personendaten enthalten. Für Tests gibt es synthetische Fixtures. Die Prüfung steckt in [tool/validate_tracked_files.dart](tool/validate_tracked_files.dart).

### GitHub Actions

Die gleiche Versionsprüfung läuft zusätzlich in GitHub Actions:

- [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) validiert Pull Requests nach `develop` und `master` mit Versionscheck, Formatierung, Analyse und Tests.
- [deploy-android-internal.yml](.github/workflows/deploy-android-internal.yml) baut ein Android App Bundle und deployed es nach Pushes auf `develop`, nach gemergten Pull Requests auf `master` oder manuell in den internen Play-Track. Die `.env` entsteht aus [.env.example](.env.example): Wiredash, Geoapify und Hitobito kommen wie in Xcode Cloud nur aus CI (Secrets `PROD_WIREDASH_SECRET`, `PROD_WIREDASH_PROJECT_ID`, `GEOAPIFY_KEY`, `HITOBITO_OAUTH_CLIENT_SECRET`; Variablen `HITOBITO_BASE_URL`, `HITOBITO_OAUTH_CLIENT_ID`, `HITOBITO_OAUTH_REDIRECT_URI`) und erzeugen bei fehlenden Werten eine Warnung. Alle übrigen Keys übernehmen den Default aus `.env.example`.
- [create-github-release.yml](.github/workflows/create-github-release.yml) erstellt nach gemergten Pull Requests auf `master` oder manuell einen GitHub Release auf Basis der Version aus [pubspec.yaml](pubspec.yaml) und der Eintraege aus [assets/changelog.json](assets/changelog.json).

Die Workflows laufen nur für den Bereich, der sich geändert hat:

- In [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) entscheidet der Job `changes` anhand der geänderten Pfade. Die Flutter-Validierung und `Update check Android` laufen nur bei App-Änderungen (`lib/`, `test/`, `integration_test/`, `assets/`, `android/`, `ios/`, `tool/`, `pubspec.*`, `analysis_options.yaml`, `.env.example`), der macOS-Job nur bei Änderungen an `ios/` oder `pubspec.*`. Übersprungene Pflicht-Checks gelten als bestanden, reine Server- oder Doku-PRs sind also ohne App-Lauf mergebar. PRs, die nur `docs/version.json` oder den Changelog ändern, prüfen ausschließlich die Versionskonsistenz. Auch der Versionssprung für `master`-PRs wird nur bei App-Änderungen verlangt.
- [server-validate.yml](.github/workflows/server-validate.yml) und [server-deploy.yml](.github/workflows/server-deploy.yml) laufen nur bei Änderungen unter `server/`.
- Deploy nach Play (ohne `ios/`), GitHub Release und Version-Reminder-PRs laufen nur, wenn der Merge App-Dateien enthält; `docs/version.json` allein löst sie nicht aus.
- Ein neuer Push auf einen PR bricht den noch laufenden Validierungslauf ab.

Neue App-Verzeichnisse oder -Dateien müssen in diese Pfadlisten aufgenommen werden.

Der Job `Validate tracked files` in [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) läuft bei jedem PR. Er prüft dieselben Sperrmuster wie der Pre-Commit-Hook, zusätzlich über die gesamte Git-Historie (`dart tool/validate_tracked_files.dart --history`). Damit fällt auch ein Branch auf, der noch auf der Historie vor der Bereinigung vom Oktober 2026 basiert.

Zusätzlich validieren [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) und [deploy-android-internal.yml](.github/workflows/deploy-android-internal.yml) die Env-Vorlage über [tool/validate_env_files.dart](tool/validate_env_files.dart), damit neue oder entfernte Keys nicht unbemerkt an [.env.example](.env.example) vorbeilaufen.

Für PRs enthält [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) jetzt auch eine macOS-Jobstufe, die native iOS-Swift-Quelltexte formatiert und den iOS-Runner mit `xcodebuild` für den Simulator kompiliert.

Android wird in PRs als Release-App-Bundle gebaut und auf 16-KB-Seitenunterstützung geprüft. Der Pflicht-Check `Update check Android` installiert auf einem Emulator die letzte Release-Version (neuester Tag unterhalb der pubspec-Version, aktuell `v0.2.8`) mit Testdaten, aktualisiert darauf auf den PR-Stand und prüft den Start. Anschließend startet er das Release-Bundle so, wie Google Play es ausliefert (siehe [tool/upgrade_test/run_upgrade_test.sh](tool/upgrade_test/run_upgrade_test.sh) und [tool/android/](tool/android/)).

Dadurch kann eine inkonsistente Versionierung nicht unbemerkt in den Hauptbranch gelangen, auch wenn lokal kein Hook aktiviert ist. Der GitHub Release enthält bewusst nur Tag und Release-Notizen, aber kein angehängtes Android-Binärfile.

Der iOS-Release-Pfad läuft weiterhin außerhalb von GitHub Actions über Xcode Cloud beziehungsweise App Store Connect.
Das Xcode-Cloud-Skript [ios/ci_scripts/ci_pre_xcodebuild.sh](ios/ci_scripts/ci_pre_xcodebuild.sh) erzeugt die lokale [.env](.env) dabei anhand der Keys aus [.env.example](.env.example).
Wenn Env-Keys geändert werden, müssen deshalb Xcode-Cloud-Variablen und [.env.example](.env.example) synchron gehalten werden.

Beim Merge eines Pull Requests nach `master` erstellt [version-reminder-prs.yml](.github/workflows/version-reminder-prs.yml) automatisch zwei Pull Requests:

- einen für Android
- einen für iOS

Diese PRs aktualisieren jeweils den passenden Eintrag in [docs/version.json](docs/version.json) auf die neue Versionsnummer.
Sie dienen als Erinnerung und sollen erst dann gemerged werden, wenn die jeweilige Store-Version wirklich verfügbar ist.

Direkte Pushes nach `master` werden als Hotfixes behandelt und lösen bewusst keine Release-, Deploy- oder Versionierungs-Workflows aus.

### Storybook

Storybook ist Teil der UI-Absicherung.

Zum Starten:

```sh
flutter run -t lib/main_storybook.dart
```

### Karten-Geodaten

Für die Kartenansicht unter Einstellungen wird zur Laufzeit kein Shapefile geladen, sondern ein leichtgewichtiges GeoJSON-Asset unter [assets/maps/dioeceses.geojson](assets/maps/dioeceses.geojson).

Die Quelldaten stammen aus generalisierten Bistumsgrenzen im Shapefile-Format und werden vorab lokal nach WGS84/EPSG:4326 konvertiert. Das Konvertierungsskript liegt unter [tool/convert_bistum_shapefile.py](tool/convert_bistum_shapefile.py), reduziert den Attributsatz auf die für die App benötigten Felder und kanonisiert die Nutzerbezeichnungen auf stabile fachliche Diözesanverbände. Der Offizialatsbezirk Oldenburg wird dabei fachlich dem Diözesanverband Münster zugeordnet und bereits im GeoJSON zusammengeführt.

Die Vereinfachung bleibt bewusst konfigurierbar. Aktuell ist das eingebundene Karten-Asset mit 85 Prozent Genauigkeit erzeugt, also mit 15 Prozent Vereinfachung:

```sh
python3 -m venv .venv
./.venv/bin/pip install pyshp pyproj
./.venv/bin/python tool/convert_bistum_shapefile.py --simplify-percent 15
```

Die aktuell eingebundene Kartenansicht kombiniert generalisierte Bistumsgrenzen als fachliche Näherung für DPSG-Diözesen mit Stammstandorten aus dem Store-Locator-Pfad. Beim Auswählen eines Stammes oder einer Diözese zeigt die Karte den Namen und, sofern gepflegt, einen direkten Website-Link an. Weitere Kartenebenen bauen künftig auf demselben GeoJSON-basierten Laufzeitpfad auf.

### Dokumentationsstil

Für deutschsprachige Fließtexte in [README.md](README.md), unter [docs](docs) und unter [specs](specs) gilt UTF-8-Schreibweise mit echten Umlauten und ß.
ASCII bleibt auf technische Literale begrenzt, insbesondere für Code, Dateinamen, Pfade, URLs, Env-Keys, CLI-Beispiele, Identifier und API-Felder.

### Hitobito OAuth

Für die Entwicklung gegen die Demo-Instanz verwendet die App eine reduzierte Hitobito-Konfiguration über `.env` mit `HITOBITO_BASE_URL`, Client-ID, Client-Secret und Redirect-URI. Authorization-, Token-, Discovery-, Profil- und People-Endpunkte werden daraus im Code abgeleitet. Client-ID und Client-Secret können zusätzlich in den Entwickler-Werkzeugen (nur Debug- und Profile-Builds, unter Hilfe & Diagnose) zur Laufzeit testweise überschrieben werden; im Release gilt immer die `.env`, ein gespeicherter Override wird ignoriert; die Werte werden lokal sicher gespeichert und erst nach erfolgreicher Prüfung übernommen.
Neue Env-Keys müssen immer auch in [.env.example](.env.example) enthalten sein, weil lokale Validierung, GitHub Actions und Xcode Cloud dieses Template als Referenz verwenden.

### Hitobito-Arbeitskontextmodell

Für die aktuelle Hitobito-Ausbaustufe gilt fachlich folgendes Modell:

- Die App arbeitet immer in genau einem aktiven Arbeitskontext.
- Ein Arbeitskontext ist immer genau ein Layer. Hitobito-Rechte können die darin sichtbaren Personen und Gruppen verkleinern, ohne dass dadurch ein anderer Arbeitskontext entsteht.
- Technisch sichtbare Layer aus Hitobito sind nicht automatisch App-relevante Layer. Die App bietet nur Layer an, die sich aus eigenen Rollen mit arbeitskontextrelevanten Lese- oder Schreibrechten ableiten lassen.
- `contact_data` und ähnliche Zusatzrechte erzeugen für sich allein keinen eigenen Arbeitskontext und erweitern die angebotene Layerliste nicht.
- Die App arbeitet im MVP mit genau dem aus Hitobito lesbar zurückgelieferten Bestand. Ein eigener Rechtebaum wird dabei nicht zusätzlich in der App modelliert.
- Gruppen innerhalb eines Arbeitskontexts sind in der App primär Filter oder Teilmengen und keine eigenständigen Hauptkontexte.
- Gruppenrechte wie `group_read` oder `group_and_below_read` können einen Layer für die App relevant machen, schränken aber primär die sichtbare Teilmenge innerhalb dieses Layers ein.
- Layerrechte wie `layer_read`, `layer_full`, `layer_and_below_read` oder `layer_and_below_full` bestimmen, welche Layer als Arbeitskontexte angeboten werden.
- Für den MVP wird die In-App-Stufe global im Code über zentrale Regeln zu Hitobito-Gruppentypen abgeleitet. Eine einzelne Gruppe entspricht darüber höchstens einer In-App-Stufe.
- Personen werden Gruppen in der App über ihre Rollen zugeordnet. Hat eine Person Rollen in mehreren Gruppen, kann sie in mehreren Filtern erscheinen.
- Leere Gruppen ohne Personen werden in der Leseansicht nicht angezeigt.
- Sonstige Gruppen sind keine vordefinierten Hauptfilter, können aber in benutzerdefinierten Filtern genutzt werden.
- Leere Layer bleiben grundsätzlich zulässige Arbeitskontexte, weil sie für erste Anlage- oder Aufbauprozesse relevant sein können.
- Ohne mindestens ein relevantes Layer- oder Gruppen-Lese- beziehungsweise Schreibrecht kann die App fachlich nicht genutzt werden. Stellt ein Sync das fest, meldet die App ab, löscht die lokalen Daten und nennt auf dem Login-Bildschirm den Grund. Bleibt nach geänderten Rechten noch etwas lesbar, ersetzt der Sync die Daten durch den neuen Stand.
- Der initiale Arbeitskontext wird aus dem Primary Layer der Person bestimmt, sofern dieser innerhalb der relevanten Layer liegt. Falls dies ausnahmsweise nicht sinnvoll bestimmbar ist, wird der erste relevante Layer aus einer stabil sortierten Liste verwendet.
- Suche, Mitgliedsliste, Statistik und weitere Ansichten arbeiten jeweils nur innerhalb des aktiven Arbeitskontexts.
- Unterlayer gehören nicht automatisch zum aktiven Arbeitskontext. Sie werden nur über einen bewussten Kontextwechsel geöffnet.
- Offline verfügbar ist in der ersten Ausbaustufe genau ein Arbeitskontext. Beim Wechsel wird der lokal gespeicherte Kontext ersetzt.

Die ausführliche Fassung dieses Konzepts liegt in [specs/hitobito-arbeitskontext-konzept.md](specs/hitobito-arbeitskontext-konzept.md).

## Funktionsweise

Die App ist darauf ausgelegt, sich direkt mit dem NaMi-Backend zu verbinden, sodass keine Mitgliedsdaten auf externen Servern dieser App gespeichert oder verarbeitet werden.

Für Hitobito gilt aktuell: Die App muss beim ersten Start erfolgreich per Hitobito angemeldet werden, damit Profil- und Mitgliedsdaten erstmals lokal geladen werden können. Danach bleiben die lokal verschlüsselten Daten auch ohne erreichbares Hitobito lesbar. Aktualisierungsversuche laufen weiter über das konfigurierte Intervall `HITOBITO_REFRESH_INTERVAL_HOURS`. Zusätzlich prüft die App während aktiver Nutzung, ob ein zuvor blockierter Sync wieder möglich ist, etwa bei verfügbarer WLAN-Verbindung oder wenn die Einstellung für mobile Daten den Netzwerkzugriff wieder erlaubt. Schlägt ein Update fehl, bleiben die vorhandenen lokalen Daten weiter nutzbar. Ein nur teilweise geladenes Update gilt ebenfalls als fehlgeschlagen: Die App behält den vorherigen Stand, und Datenstand und Löschfrist bleiben unverändert. Der Hinweis auf das fehlgeschlagene Update blendet sich nach etwa 15 Sekunden aus. Verbindungen, die weder WLAN noch Mobilfunk sind (etwa nur VPN), behandelt die App dabei wie mobile Daten. Nach manuellem Logout oder wenn der letzte erfolgreiche Datenstand älter als `HITOBITO_DATA_MAX_AGE_DAYS` ist, werden die lokalen Hitobito-Daten gelöscht. Vor einem manuellen Logout versucht die App, noch nicht gesendete Personenänderungen zu senden; bleiben danach welche übrig, fragt sie nach, bevor diese mit dem Logout verloren gehen.

Läuft ein Hitobito-Zugriff mit `401` in eine abgelaufene Sitzung, versucht die App zunächst den technischen Retry-Pfad mit aufgefrischtem Token. Eine erneute Anmeldung im Browser startet sie nur bei einer Nutzeraktion. Automatische Zugriffe wie Start-, Intervall- und Verbindungs-Sync oder das Nachsenden vorgemerkter Änderungen öffnen keinen Login, sondern zeigen einmal den Hinweis, dass eine erneute Anmeldung nötig ist. Der zuletzt geladene Arbeitskontext bleibt dabei erhalten. Gelöscht wird weiterhin nur bei manuellem Logout, nach Ablauf von `HITOBITO_DATA_MAX_AGE_DAYS` oder wenn kein lesbarer Layer mehr übrig ist.

Ist die App-Sperre aktiv und noch nicht entsperrt, finden keine Hitobito-Zugriffe statt; Sync und Nachsenden laufen erst nach der Entsperrung. Ein Logout beendet laufende Vorgänge: Was sie danach noch liefern, wird verworfen und nicht gespeichert. Nach einer Neuinstallation ist eine neue Anmeldung nötig, auch wenn der iOS-Schlüsselbund noch eine frühere Sitzung enthält.

Personenänderungen werden im Hitobito-Schreibpfad nicht mehr pauschal am globalen `updatedAt` abgebrochen. Die App vergleicht Basisstand, lokalen Bearbeitungsstand und aktuellen Serverstand pro Änderungseinheit. Unabhängige Änderungen werden automatisch zusammengeführt. Nur wenn dieselbe Änderungseinheit unterschiedlich geändert wurde oder ein späterer Retry einen nicht direkt zuordenbaren Validierungsfehler meldet, entsteht ein eigener Problemlösungsfall pro Mitglied. Die aktuelle Nutzerdokumentation dazu liegt unter [docs/konfliktdialog.markdown](docs/konfliktdialog.markdown).

Wenn Analytics in der App aktiviert sind, protokolliert die App zusätzlich fachliche Tracking-Ereignisse für Bearbeiten, Retry und Problemlösungsfälle. Die Übersicht der derzeit vorhandenen Wiredash-Events liegt unter [docs/wiredash.markdown](docs/wiredash.markdown).

Für die geplante Hitobito-Weiterentwicklung wird dieses Caching künftig an den jeweils aktiven Arbeitskontext gekoppelt. Die App soll dabei im ersten Schritt genau einen lokalen Arbeitskontext vorhalten und diesen bei einem bewussten Kontextwechsel ersetzen.

## Aktuelle Funktionen

- Mitglieder und deren Details auflisten, sortieren und filtern
  - Stufenfilter und benutzerdefinierte Filtergruppen auf Basis von Gruppen- und Rollenzuordnungen verwenden.
  - Die Mitgliedsdetails zeigen im Kopf Alter, Pronomen, Geschlecht und alle aktiven Stufenrollen.
    - **Daten:** Kacheln zum nächsten Geburtstag (heute und in den nächsten 7 Tagen hervorgehoben) und zur Mitgliedsdauer, dazu Geschwister im selben Hitobito-Haushalt. Weitere Telefonnummern, E-Mails und Zusatzadressen sind eingeklappt.
    - **Rollen:** Pfadfinder-Verlauf mit Kennzahlen und Bahnen je Stufe. Kinder ohne Leitung sehen statt der Leitungsjahre den nächsten Stufenwechsel (jetzt, ab oder bis Jahr). Darunter ein Zeitstrahl aller Rollen, Rollen anderer Layer sind standardmäßig ausgeblendet.
    - **Qualifikationen:** EFZ-Status als kompakte Zeile mit Download der Antragsunterlagen, darunter die Qualifikationen aus Hitobito. Beides wird beim Sync geladen und ist offline verfügbar.
  - Adresse und Entfernung zum Stammesheim auf der Karte anzeigen; ist die Karte nicht verfügbar, erscheint eine flache Hinweisfläche mit passender Aktion.
  - Wie in den Kontakten E-Mails schreiben und einen Anruf starten
- Mitglieder und Tätigkeiten bearbeiten, erstellen und löschen/Mitgliedschaft beenden
- Mitgliedsdaten sind nach erstem erfolgreichem Hitobito-Login und initialem Laden offline verfügbar; Aktualisierungen werden im konfigurierten Hitobito-Refresh-Intervall versucht
- Schlägt das Senden einer Personenänderung wegen eines retrybaren Remote-Fehlers fehl, wird die Änderung lokal vorgemerkt und während aktiver App-Nutzung automatisch erneut versucht, sobald Senden wieder erlaubt ist; zusätzlich bleibt ein manueller Retry über Hilfe & Diagnose möglich
- Echte Konflikte bei Personenänderungen sowie bestimmte spätere Validierungsfehler werden als Problemlösungsfall pro Mitglied gespeichert. Offene Fälle sind über Einstellungen, Mitglieddetails und die Mitgliederliste sichtbar und können von dort erneut geöffnet werden.
- Die App erfasst bei aktivierter Analytics-Option Tracking-Ereignisse für Bearbeiten, Retry und Problemlösungsfälle, damit Konflikte und nicht automatisch lösbare Fälle fachlich ausgewertet werden können.
- Der Statistik-Tab zeigt den aktiven Stamm als Kacheln in den Themen Überblick, Stufen und Entwicklung: im Kopf die Personenzahl mit Stufenband, darunter unter anderem Gruppen je Stufe, Altersstruktur, Alter in Zahlen, Stufenwechsel zum eingestellten Stichtag, Neue in 12 Monaten und Bindung, Verlauf, Geschlecht, Konfession und Wohnorte. Jede Gruppe ist über die Gruppen-Kachel erreichbar: 2×2 zeigt bis 6 Gruppen als Liste, bis 12 in zwei Spalten und darüber als Chips je Stufe; 2×1 zeigt bei höchstens zwei Gruppen eine Spalte je Gruppe und sonst „Stufen“, wobei eine Stufe mit mehreren Gruppen eine Auswahl öffnet. Der Kachel-Titel öffnet die Auswahl aller Gruppen. Die Gruppendetailseite zeigt dieselben Kacheln für die Gruppe, ihr Titel wechselt zu einer anderen Gruppe. Die übrigen Kacheln sind reine Anzeige.
  - Wer nur einzelne Gruppen lesen darf (z. B. `group_read` als Leitung), sieht im Stamm-Tab nur das Thema Überblick mit den lesbaren Gruppen und einer eigenen Standardbelegung (Gruppen, Altersstruktur in 2×1, Stufenwechsel, Neue in 12 Monaten, Geschlecht, Konfession, Standorte). Der Bund-Tab vergleicht dann die eigene Gruppe mit Gruppen derselben Stufe.
  - Über „Bearbeiten“ lässt sich der Überblick je Stamm anpassen: Kacheln aus einem Katalog hinzufügen, entfernen (mit Rückgängig), durch langes Drücken verschieben und über die Ecke in den erlaubten Größen 1×1, 2×1 oder 2×2 ändern. Eigene Zählkacheln nutzen dieselben Regeln wie die eigenen Gruppen der Mitgliederliste. Zielwerte (Gruppengröße je Stufe, Neue pro Jahr) setzen Marken in den Kacheln und sind anfangs leer. Die festen Themen Stufen und Entwicklung lassen sich ausblenden. „Überblick zurücksetzen“ stellt nach einer Rückfrage die Standardbelegung wieder her; eigene Kacheln bleiben am Ende erhalten, Zielwerte unverändert.
  - Für den Verlauf merkt sich die App höchstens einmal im Monat die Summen des Stamms (Personen, Kinder und Jugendliche, Leitende, je Stufe), längstens 24 Monate. Verlauf und Kachel-Einstellungen liegen nur auf dem Gerät und werden beim vollständigen App-Reset gelöscht.
- Optionaler bundesweiter Vergleich im Statistik-Tab „Bundesweit“: Nach ausdrücklicher Einwilligung teilt die App etwa wöchentlich zusammengefasste Zahlen je Stufengruppe und, bei Leserechten auf den ganzen Stamm, stammweite Zahlen mit dem Statistikserver (`server/`) und zeigt dafür Median und Durchschnitt teilnehmender Stämme, je Stufe und je Gruppe. Wer nur die eigene Gruppe lesen darf (z. B. `group_read`), teilt nur deren Zahlen. Die Einwilligung gilt je Stamm: Wer mehrere Stämme sieht, gibt jeden einzeln frei. Ohne Einwilligung lädt der Tab zur Teilnahme ein; bei zu wenig teilnehmenden Stämmen oder einem nicht erreichbaren Server zeigt er einen Hinweis. Ist `STATS_SERVER_URL` nicht gesetzt, meldet der Tab den Vergleich als nicht verfügbar. Die Einwilligung lässt sich in den App-Einstellungen widerrufen.
- Demo-Zugang ohne Login: Auf dem Anmeldebildschirm öffnet „Demo ansehen“ eine Auswahl von drei Zugängen zum erfundenen Bezirk Silbertal, zum Beispiel für die App-Store-Prüfung, für Interessierte ohne Hitobito-Zugang oder für Vorführungen. Jeder Zugang hat die Rechte, die seine Rolle in Hitobito hätte, und sieht nur das, was Hitobito dafür liefern würde:
  - Stammesvorstand (`layer_and_below_read` im Stamm Silberfels): alle Mitglieder des Stamms.
  - Leitung (`group_read` im Trupp Kompass): nur die Mitglieder der eigenen Gruppe.
  - Bezirksvorstand (`layer_and_below_read` im Bezirk Silbertal): startet im Bezirk und wechselt im Profil über „Layer wechseln“ in die Stämme Silberfels und Birkenhain.

  Die Demo ist nur lesend, spricht Hitobito nicht an und hält alle Daten nur im Speicher. Für den bundesweiten Vergleich sendet sie an den Mock-Statistikserver `mock-namiapp.scout-link.de` (siehe `server/deploy/README.md`). Beendet wird die Demo über die Einstellungen oder über Abmelden. Der Demo-Modus bleibt samt gewähltem Zugang auch über einen Neustart der App erhalten. Außer dem Ereignis „Demo genutzt“ sendet die Demo keine Nutzungsdaten, auch wenn Analytics aktiviert ist.
- Empfehlung für den nächsten Stufenwechsel eines Mitglieds.
  - Die gewünschte Altersgrenzen der Stufen können angepasst werden.
  - Stufenwechsel durchführen
- Führungszeugnis-Antragsunterlagen herunterladen.
- Qualifikationen-Übersicht unter Einstellungen → Schnellzugriff, Teil des Supporter-Pakets:
  - Je Qualifikation (EFZ, Präventionsschulung, Erste Hilfe und weitere aus Hitobito) zeigt sie, wie viele im Personenkreis sie erfüllen, wo sie fehlen und was bald abläuft.
  - Einstellbar sind die angezeigten Arten mit ihrer Reihenfolge, je Art der Personenkreis (Regeln aus Rollenart, Stufe, Rollentyp und Alter) und Erinnerungen per Mitteilung.
  - Die Daten stammen aus dem Sync und sind offline verfügbar. Die Einstellungen gelten pro App und überstehen das Abmelden.
  - Bis zur Store-Anbindung schaltet ein Testschalter in den Entwickler-Werkzeugen den Supporter-Zugang frei; er wirkt nur in Debug- und Profile-Builds.
- Unter Einstellungen → Benachrichtigungen erinnert die App an die eigenen Qualifikationen (an/aus, Arten, Tage vorher), als Mitteilung und als Meldung in der App.
- Unter Einstellungen → Benachrichtigungen lassen sich Geburtstagserinnerungen für gewählte Stufen einschalten (Leitende unter „Leitung“). Die App plant sie lokal als Mitteilung am Geburtstag um 9 Uhr, für bis zu 30 Geburtstage in den nächsten 60 Tagen. Der Text nennt nur Vorname, Initial des Nachnamens und Alter.
- Unter Einstellungen → Erscheinungsbild lassen sich Hell/Dunkel, eine Farbpalette, ein alternatives App-Icon (Pakete mit Morgen, Abend und Nacht; unter iOS zusätzlich „Automatisch“ passend zum Hell/Dunkel-Modus), ein animierter Hintergrund für die Kopfbereiche von Mitgliederliste, Statistik, Stufenwechsel und Einstellungen und ein Supporter-Badge wählen. Das Badge erscheint im eigenen Profil und beim eigenen Eintrag in der Mitgliederliste. Supporter-Optionen schaltet bis zur Store-Anbindung der Testschalter in den Entwickler-Werkzeugen frei (nur Debug- und Profile-Builds); die Quellen der Designs und die Export-Skripte liegen unter `design/supporter/`.
- Das eigene Profil wird nach dem Login über Hitobito OAuth geladen und zeigt nami-id, E-Mail, bevorzugte Sprache als Sprachbadge und die zugewiesenen Rollen.
- Wenn Hitobito später nicht erreichbar ist oder eine erneute Anmeldung für Updates erforderlich wird, bleibt der lokale Datenstand bis zum Ablauf von `HITOBITO_DATA_MAX_AGE_DAYS` nutzbar; die App zeigt dazu einen fachlichen Hinweis statt einer generischen Plattformfehlermeldung.
- Die Stamm-Einstellungen und Hilfe & Diagnose bleiben auch dann erreichbar, wenn noch kein Login vorliegt oder der Arbeitskontext nicht initialisiert werden konnte. Das Profil ist nur ohne Login gesperrt. Kann der Arbeitskontext nicht geladen werden, bleiben Profil und Abmelden erreichbar; der Fehlerbildschirm bietet neben „Erneut versuchen“ auch „Abmelden“ und zeigt eine App-Meldung statt der Serverantwort (Details unter Hilfe & Diagnose → Protokolle).
- Unter Einstellungen steht zusätzlich eine Kartenansicht zur Verfügung, die generalisierte Bistumsgrenzen für DPSG-Diözesen, Stammstandorte und optionale Website-Links für ausgewählte Stämme oder Diözesen anzeigt.
- Die App-Sprache wird nach dem Login auf Basis der bevorzugten Profilsprache gesetzt. Unbekannte oder fehlende Sprachcodes fallen auf Deutsch zurück.
- Jeder Nutzer sieht auch nur die Funktionen, die er aufgrund seiner Rechte ausführen kann. Die Rechte sind im eigenen Profil aufgelistet.
- Jeder Nutzer hat die Möglichkeit das Bearbeiten von Daten zu deaktiven und braucht so keine Angst haben 'Etwas kaput zu machen'
- Erfolge belohnen regelmäßige Nutzung mit Abzeichen in den Stufen Bronze, Silber, Gold, Platin und Diamant (Tage mit geöffneter App, gespeicherte Mitgliedsänderungen, Tage mit geöffneter Statistik) sowie mit einmaligen Abzeichen für App-Bewertung und Feedback. Die Übersicht ist über das Profil erreichbar. Erfolge gelten pro Gerät, unabhängig vom angemeldeten Konto: Sie werden nur lokal gespeichert, nicht synchronisiert, bleiben beim Abmelden erhalten und werden nur beim vollständigen App-Reset gelöscht. Der Demo-Zugang zeigt die Erfolge des Geräts; was in der Demo dazukommt, wird nicht gespeichert und kann nach einem Neustart erneut erscheinen.

## Geplante Funktionen

- Adresse automatisch vervollständigen über Geoapify im Online-Bearbeiten-Pfad; die separate Adressvalidierung bleibt auf Offline- und spätere Sync-Fälle begrenzt
- Mitglieder anlegen per Texterkennung / Foto vom Anmeldebogen
- Export von Zuschusslisten
- Kalenderintegration für Geburtstage
- Detailansichten hinter den Statistik-Kacheln, etwa wann Mitglieder den Stamm verlassen und wann sie kommen
- Weitere fachliche Kartenebenen auf Basis der neuen Karteninfrastruktur

## Externe Apis

- [Geoapify](https://www.geoapify.com): Autovervollständigung von Adressen und Geokodierung für Mitglieds- und Stammeskarte sowie die Standorte-Kachel der Statistik (Free Limit 3000 Requests / day). Gesendet wird die Adresse ohne c/o-Zeile, nur wenn die Netzregel es erlaubt; Koordinaten werden lokal zwischengespeichert. Nach HTTP 429 pausiert die App alle Geokodierungen (laut `Retry-After`, sonst eine Stunde).
- [MapTiler](https://www.maptiler.com): konfigurierbarer Tile-Provider für Kartenansicht und Offline-Tiles
- [OpenStreetMap Tiles](https://operations.osmfoundation.org/policies/tiles/): Fallback, wenn kein expliziter Tile-Endpoint konfiguriert ist
- [openiban](https://openiban.com): Validierung der IBAN beim anlegen eines Nutzers (Unlimited)

## Dokumentation

- [docs/index.markdown](docs/index.markdown) ist die Startseite des GitHub-Pages-Wikis.
- [docs/konfliktdialog.markdown](docs/konfliktdialog.markdown) beschreibt das aktuelle Verhalten des Problemlösungsfalls.
- [docs/wiredash.markdown](docs/wiredash.markdown) listet die aktuell implementierten Wiredash-Trackings auf.
