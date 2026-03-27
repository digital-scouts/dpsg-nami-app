# NaMi

<a href="https://apps.apple.com/de/app/nami/id6468066816">
    <img src="./assets/workfiles/Download_on_the_App_Store_Badge_DE_RGB_blk_092917.svg" alt="Download für iOS" height="50">
</a>
<a href="https://play.google.com/store/apps/details?id=de.jlange.nami.app">
    <img src="./assets/workfiles/GetItOnGooglePlay_Badge_Web_color_German.png" alt="Download für Android" height="50" >
</a>

![wakatime](https://wakatime.com/badge/user/f75702c6-6ecd-478f-a765-9c0a07c62d50/project/c30b8bfa-fe60-4da1-9a32-9c86bad66605.svg)
[![Watch](https://img.shields.io/github/watchers/JanneckLange/dpsg-nami-app?label=Watch)](https://github.com/JanneckLange/dpsg-nami-app/subscription)

Master:

[![Release](https://img.shields.io/github/v/release/janneckLange/dpsg-nami-app?display_name=tag&include_prereleases)](https://github.com/JanneckLange/dpsg-nami-app/releases)
[![Commit](https://shields.io/github/last-commit/JanneckLange/dpsg-nami-app/master)](https://github.com/JanneckLange/dpsg-nami-app/commits/master)

Develop:

[![Validate](https://github.com/JanneckLange/dpsg-nami-app/actions/workflows/validate-pull-requests.yml/badge.svg)](https://github.com/JanneckLange/dpsg-nami-app/actions/workflows/validate-pull-requests.yml)
[![Commit](https://shields.io/github/last-commit/JanneckLange/dpsg-nami-app/develop)](https://github.com/JanneckLange/dpsg-nami-app/commits/develop)

NaMi steht für die Namentliche Mitgliedermeldung der Deutschen Pfadfinderschaft Sankt Georg (DPSG). Diese App richtet sich speziell an Gruppenleiter:innen der DPSG und ermöglicht den mobilen, offline Zugriff auf Mitgliederdaten. Dank vielseitiger Sortier- und Filterfunktionen sowie grundlegender Bearbeitungsoptionen bietet die App eine unverzichtbare Unterstützung im Stammesalltag.

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
Sie enthält pro Plattform die zuletzt als verfuegbar markierte Version, die minimale unterstuetzte Version und den Store-Link.
Diese Datei beschreibt bewusst nicht den aktuellen Entwicklungsstand, sondern den tatsaechlich freigegebenen Stand pro Plattform.
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

### GitHub Actions

Die gleiche Versionsprüfung läuft zusätzlich in GitHub Actions:

- [validate-pull-requests.yml](.github/workflows/validate-pull-requests.yml) validiert Pull Requests nach `develop` und `master` mit Versionscheck, Formatierung, Analyse und Tests.
- [deploy-android-internal.yml](.github/workflows/deploy-android-internal.yml) baut ein Android App Bundle und deployed es nach Pushes auf `develop`, nach gemergten Pull Requests auf `master` oder manuell in den internen Play-Track.
- [create-github-release.yml](.github/workflows/create-github-release.yml) erstellt nach gemergten Pull Requests auf `master` oder manuell einen GitHub Release auf Basis der Version aus [pubspec.yaml](pubspec.yaml) und der Eintraege aus [assets/changelog.json](assets/changelog.json).

Zusätzlich validieren die CI-Workflows die Env-Vorlage über [tool/validate_env_files.dart](tool/validate_env_files.dart), damit neue oder entfernte Keys nicht unbemerkt an [.env.example](.env.example) vorbeilaufen.

Dadurch kann eine inkonsistente Versionierung nicht unbemerkt in den Hauptbranch gelangen, auch wenn lokal kein Hook aktiviert ist. Der GitHub Release enthaelt bewusst nur Tag und Release-Notizen, aber kein angehaengtes Android-Binaerfile.

Der iOS-Release-Pfad laeuft weiterhin ausserhalb von GitHub Actions ueber Xcode Cloud beziehungsweise App Store Connect.
Das Xcode-Cloud-Skript [ios/ci_scripts/ci_pre_xcodebuild.sh](ios/ci_scripts/ci_pre_xcodebuild.sh) erzeugt die lokale [.env](.env) dabei anhand der Keys aus [.env.example](.env.example).
Wenn Env-Keys geändert werden, müssen deshalb Xcode-Cloud-Variablen und [.env.example](.env.example) synchron gehalten werden.

Beim Merge eines Pull Requests nach `master` erstellt [version-reminder-prs.yml](.github/workflows/version-reminder-prs.yml) automatisch zwei Pull Requests:

- einen für Android
- einen für iOS

Diese PRs aktualisieren jeweils den passenden Eintrag in [docs/version.json](docs/version.json) auf die neue Versionsnummer.
Sie dienen als Erinnerung und sollen erst dann gemerged werden, wenn die jeweilige Store-Version wirklich verfuegbar ist.

Direkte Pushes nach `master` werden als Hotfixes behandelt und loesen bewusst keine Release-, Deploy- oder Versionierungs-Workflows aus.

### Storybook

Storybook ist Teil der UI-Absicherung.

Zum Starten:

```sh
flutter run -t lib/main_storybook.dart
```

### Hitobito OAuth

Fuer die Entwicklung gegen die Demo-Instanz verwendet die App eine reduzierte Hitobito-Konfiguration ueber `.env` mit `HITOBITO_BASE_URL`, Client-ID, Client-Secret und Redirect-URI. Authorization-, Token-, Discovery-, Profil- und People-Endpunkte werden daraus im Code abgeleitet.
Neue Env-Keys muessen immer auch in [.env.example](.env.example) enthalten sein, weil lokale Validierung, GitHub Actions und Xcode Cloud dieses Template als Referenz verwenden.

## Funktionsweise

Die App ist darauf ausgelegt, sich direkt mit dem NaMi-Backend zu verbinden, sodass keine Mitgliedsdaten auf externen Servern dieser App gespeichert oder verarbeitet werden.

Teile der Mitgliedsdaten-Funktionalitaet befinden sich noch in Umsetzung. Geplante Sicherheitsmassnahmen wie eine verschluesselte lokale Speicherung dieser Daten sind noch nicht vollstaendig umgesetzt und sollten daher noch nicht als abgeschlossen betrachtet werden.

## Aktuelle Funktionen

- Mitglieder und deren Details auflisten, sortieren und filtern
  - Adresse und Entfernung zum Stammesheim auf der Karte anzeigen.
  - Über Grafiken und Auflistung den Tätigkeitsverlauf eines Mitglieds ansehen.
  - Wie in den Kontakten E-Mails schreiben und einen Anruf starten
- Mitglieder und Tätigkeiten bearbeiten, erstellen und löschen/Mitgliedschaft beenden
- Mitgliedsdaten sind offline verfügbar und können nach belieben synchronisiert werden
- Statistiken geben einen Einblick in die aktuelle Mitgliederanzahl und Altersstruktur
- Empfehlung für den nächsten Stufenwechsel eines Mitglieds.
  - Die gewünschte Altersgrenzen der Stufen können angepasst werden.
  - Stufenwechsel durchführen
- Führungszeugniss Antragsunterlagen und Bescheinigungen herrunterladen
- Das eigene Profil wird nach dem Login ueber Hitobito OAuth geladen und zeigt nami-id, E-Mail, bevorzugte Sprache als Sprachbadge und die zugewiesenen Rollen.
- Die App-Sprache wird nach dem Login auf Basis der bevorzugten Profilsprache gesetzt. Unbekannte oder fehlende Sprachcodes fallen auf Deutsch zurueck.
- Jeder Nutzer sieht auch nur die Funktionen, die er aufgrund seiner Rechte ausführen kann. Die Rechte sind im eigenen Profil aufgelistet.
- Jeder Nutzer hat die Möglichkeit das Bearbeiten von Daten zu deaktiven und braucht so keine Angst haben 'Etwas kaput zu machen'

## Geplante Funktionen

- Mitglieder anlegen per Texterkennung / Foto vom Anmeldebogen
- Export von Zuschusslisten
- Erinnerungen und Kalenderintegration für
  - Geburtstage
  - Ablaufende Ausbildungen (Präventionsschulung)
- Statistik historische Entwicklung im Stamm
  - Wann verlassen Mitglieder den Stamm, wann kommen sie
- Stammeskarte

## Externe Apis

- [Geoapify](https://www.geoapify.com): Autovervollständigung von Adressen beim anlegen eines Nutzers (Free Limit 3000 Requests / day)
- [openplzapi](https://www.openplzapi.org/de/): Fallback für Geoapify (Unlimited)
- [openiban](https://openiban.com): Validierung der IBAN beim anlegen eines Nutzers (Unlimited)
