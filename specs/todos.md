# Todos

Diese Liste hält nur noch die nächsten offenen Aufgaben fest. Bereits umgesetzte Arbeitskontext- und Konfliktlösungs-Tickets bleiben im Code, in Tests und im Arbeitskontext-Konzept nachvollziehbar, werden hier aber nicht mehr als aktive Aufgaben geführt.

## Status-Update: Echte Stammstatistik umgesetzt

Umgesetzt im Code:

- Statistikseiten laufen auf realen Arbeitskontextdaten statt Dummy-Daten.
- Global-Tab und Konfession wurden aus der Statistikansicht entfernt (out of scope).
- Gruppen werden dynamisch aus Gruppen + Mitgliedszuordnungen aufgebaut.
- Rollenzaehlung erfolgt als Mitglied/Leitung; Hilfsleiter wird als Leitung gezaehlt.
- Kartenmarker werden aus Mitgliederadressen aufgebaut und nutzen den globalen Adress-Hash-Cache.

Offen als Nacharbeit:

- Feldtests mit echten Layerdaten (insbesondere sehr grosse Staemme und unvollstaendige Adressen).
- Feinschliff der Statistiktexte/Lokalisierung fuer alle neuen Stati.

## Priorität 1: Stufen und Gruppen mit den neuen Testdaten konsolidieren

Ziel: Die Stufenableitung wird auf die echten Gruppentypen StammGruppeBiber, StammGruppeWoelflinge, StammGruppeJungpfadfinder, StammGruppePfadfinder und StammGruppeRover umgestellt; Beitragsarten werden als reine Ansicht ergänzt.

Nächste Aufgaben:

- Gruppentypen aus den neuen Hitobito-Testdaten eindeutig erfassen und der zentralen Stufenableitung zuordnen.
- `lib/domain/stufe/arbeitskontext_stufen_mapping.dart` auf die fünf Zieltypen umstellen.
- Biber-Sichtbarkeit als Sonderregel festhalten: Standardmäßig ausgeblendet, wenn im aktiven Stamm kein Biber vorkommt.
- Beitragsarten in der Ansicht ergänzen (kein Bearbeiten): Group::Mitglieder::OrdentlicheMitgliedschaft, Group::Mitglieder::Foerdermitgliedschaft, Group::Mitglieder::Zweitmitgliedschaft.
- Beitragsart-Regel verankern: pro Layer genau eine Beitragsart; global Ordentliche/Förder jeweils nur einmal, sonst Zweitmitgliedschaft.
- Keine Migration und keine Rückwärtskompatibilität berücksichtigen.
- Tests für Stufenableitung, Filtertreffer und Mitgliederliste aktualisieren.
- Arbeitskontext-Konzept und Aufgabenplanung synchron halten.

## Priorität 2: Offline-Sync und Problemlösungsfälle fertig prüfen

Ziel: Der bestehende Problemlösungsfall soll für spätere Sync- und Retry-Situationen belastbar sein.

Nächste Aufgaben:

- Offline-Konflikt manuell testen: Mitglied lokal ändern, Serverstand ändern, später synchronisieren, Problemlösungsfall öffnen und lösen.
- Fehlerhafte Telefonnummer offline speichern und später synchronisieren: Server-Validierungsfehler muss als Problemlösungsfall sichtbar werden.
- Automatischen Sync während aktiver App-Nutzung mit Queue-Einträgen prüfen: WLAN, erlaubte mobile Daten, gedrosselte Retry-Versuche.
- Verhalten bei ungültiger Sitzung erneut prüfen: Hinweis nur einmal anzeigen, Bearbeiten weiterhin wie im Offline-Modus möglich.

## Priorität 3: Adressvalidierung anschließen

Ziel: Adressprobleme aus Offline-Bearbeitung und späterem Sync sollen denselben Problemlösungsfall nutzen wie Konflikte und andere fachliche Sync-Probleme.

Nächste Aufgaben:

- Produktionspfad für Adressvalidierung definieren: wann wird geprüft, wann wird nur gespeichert, wann entsteht ein Problemlösungsfall.
- Geoapify-basierte Prüfung für spätere Retry-/Sync-Fälle anbinden, ohne den normalen Offline-Speicherpfad zu blockieren.
- Ungültige Adresse offline speichern und später synchronisieren: Adresse nicht gefunden oder semantisch unplausibel muss als Problemlösungsfall erscheinen.
- Gültige Adresse offline bearbeiten und später synchronisieren: Änderung muss ohne unnötigen Problemlösungsfall gesendet werden.

## Priorität 4: Adressbearbeitung vereinfachen

Ziel: Die spätere automatische Adressvervollständigung soll den Online-Bearbeiten-Pfad vereinfachen, ohne den Offline-Fallback zu verlieren.

Nächste Aufgaben:

- Adresssuche über den bestehenden Geoapify-Dienst als primären Online-Pfad konzipieren.
- Adresseingabe auf ein Such- und Auswahlfeld reduzieren; Bezeichnung und c/o bleiben eigene Felder.
- Land als Dropdown vorbereiten: Deutschland als Default plus Nachbarländer.
- Aktuelle strukturierte Adresseingabe als Fallback erhalten, wenn offline oder Geoapify nicht verfügbar ist.
- Prüfen, ob das Postfach-Feld im neuen Online-Pfad entfallen kann und wie bestehende Daten weiter angezeigt werden.

## Priorität 5: Nützliche Ergänzungen

- Länderflaggen auch im MemberDetail an Telefonnummern anzeigen.
- Anrufen/E-Mail buttons disable wenn keine Telefon/Mail vorhanden
- GitHub-Pages-Wiki/Userguide für Konfliktlösung, Datenspeicherung und Löschung schreiben.
- Problemlösungs-Screen prüfen: Bereich "Mitglied bearbeiten" bleibt beim Einstieg eingeklappt, kann aber gut sichtbar aufgeklappt werden.
- Debug&Tools Adress-Cache löschen button
- Einsettungen Messages bleiben stehen auch wenn sie ackn worden sind. Erst bei tab wechsel und neu öffnen von einstellungen verschwinden sie wie gewünscht.

## Task 6: Bei erststart nach Update alte daten löschen

- Kommt ein User von der alten app (Version vor 1.0.0) passt die datenstruktur nicht zur neuen App.
- Alten Datenstand komplett entfernen und app neu initalisieren um probleme zu vermeiden.

## Task 7: Erstes Laden unabhängig von WLAN

- Das erste Laden (keine Daten vorhanden) muss unabhängig von der Wlan einstellung immer gemacht werden. Ansonsten kommt es zu problemen
- Skelloton anzeigen beim ersten laden um fortschritt zu signalisieren

## Später prüfen: Arbeitskontext-Ausbau

Diese Punkte sind für den aktuellen MVP nicht blockierend, bleiben aber als spätere Produktentscheidungen relevant.

- Schreib- und Bearbeitungslogik für teilweise sichtbare Layer klären, sobald Gruppenwechsel, Rollenwechsel, Verschieben oder Neuanlage von Personen geplant werden.
- Offene API-Felder prüfen, wenn sie fachlich gebraucht werden: insbesondere Person-`created_at` und mögliche Tags. Rollen-`created_at`, `start_on` und `end_on` sind bereits im Roles-Modell berücksichtigt.
- Mehrere offline verfügbare Arbeitskontexte nur dann konzipieren, wenn ein konkreter Bedarf für parallele Offline-Layer entsteht.
- Rekursive Sichten über Unterlayer nur als eigenen Produktentscheid behandeln; sie gehören weiterhin nicht automatisch zum aktiven Arbeitskontext.
- Persönliche Teilmengen, Tags und "Meine Gruppe" erst nach Stabilisierung der bestehenden Gruppen- und Stufenfilter konkretisieren.

## Manuelle Prüfliste

- [ ] Neue Testdaten enthalten Biber, Wö, Jufi, Pfadi und Rover mit bestätigten Gruppentypen.
- [ ] Stufenfilter zeigt mit neuen Testdaten alle erwarteten Stufen korrekt an.
- [ ] Biber wird über die zentrale Stufenableitung erkannt und bei fehlendem Biber im aktiven Stamm standardmäßig ausgeblendet.
- [ ] Jufi und Pfadi werden fachlich korrekt getrennt.
- [ ] Mitglieder ohne Stufenzuordnung landen weiterhin in Rest beziehungsweise Alle anderen.
- [ ] Konfliktlösung offline getestet.
- [ ] Fehlerhafte Telefonnummer offline gespeichert und später als Problemlösungsfall geprüft.
- [ ] Gültige Adresse offline gespeichert und später erfolgreich synchronisiert.
- [ ] Ungültige Adresse offline gespeichert und später als Problemlösungsfall geprüft.
- [ ] Automatischer Sync mit vorhandenen Queue-Einträgen geprüft.

## Umsetzungsplan (integriert aus tasks.md)

### Handoff-Rahmen

- Keine Migration.
- Keine Rückwärtskompatibilität.
- Beitragsart nur Ansicht.

### Betroffene Bereiche

- lib/domain/stufe/arbeitskontext_stufen_mapping.dart
- lib/domain/stufe/usecases/ermittle_stufen_im_arbeitskontext_usecase.dart
- lib/domain/member_filters/usecases/ermittle_member_filter_treffer_usecase.dart
- lib/presentation/screens/member_people_page.dart
- lib/presentation/widgets/member_list_directory.dart
- lib/presentation/widgets/member_basis_info_card.dart
- test/ermittle_stufen_im_arbeitskontext_usecase_test.dart
- test/member_people_page_test.dart
- specs/hitobito-arbeitskontext-konzept.md
- specs/todos.md
- specs/dpsg-org-hirachie.md

## Umsetzungspakete

- P1: Stufen-Mapping auf die fünf Zieltypen konsolidieren. Umgesetzt.
- P2: Stufen-Ableitung und Filtertreffer fachlich deckungsgleich machen. Umgesetzt.
- P3: Biber-Sichtbarkeit in der Mitgliederansicht eindeutig regeln. Umgesetzt ueber dieselbe Stufen-Ableitung.
- P4: Beitragsarten in der UI konsistent als reine Anzeige führen. Umgesetzt ohne zusätzliche Fachlogik.
- P5: Zusammenspiel aus Stufen, Biber-Regel und Beitragsart gegen Regression absichern. Im Code und in gezielten Tests umgesetzt; reale Testdaten und manuelle Prüfliste bleiben offen.

### Doku-Folgen

- specs/hitobito-arbeitskontext-konzept.md auf den umgesetzten Stand abgleichen.
- specs/todos.md Fortschritt je Paket fortlaufend nachführen.
- specs/dpsg-org-hirachie.md Begriffe und Gruppentypbezüge harmonisieren.
