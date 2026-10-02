# Todos

Diese Liste führt nur offene Aufgaben. Umgesetzte Arbeitskontext-, Stufen-, Beitragsart-, Statistik- und Sync-Pakete bleiben im Code, in Tests und im Arbeitskontext-Konzept nachvollziehbar, werden hier aber nicht mehr als aktive Aufgaben geführt.

## Priorität 1: Feldtests und Doku-Abgleich

Ziel: Die bereits implementierten Stammstatistik-, Stufen-, Beitragsart- und Sync-Anpassungen mit echten Daten prüfen und die Projektdokumentation auf den aktuellen Stand bringen.

Nächste Aufgaben:

- Feldtests mit echten Layerdaten durchführen, insbesondere sehr große Stämme, unvollständige Adressen und reale Biber-/Wö-/Jufi-/Pfadi-/Rover-Gruppen.
- Statistiktexte und Lokalisierung für neue oder seltene Statusfälle prüfen und bei Bedarf nachschärfen.
- [specs/hitobito-arbeitskontext-konzept.md](hitobito-arbeitskontext-konzept.md) mit dem umgesetzten Stand zu Stufen, Beitragsarten, Rollenladen und Sync-Status abgleichen.
- Prüfen, ob zusätzliche Begriffs- oder Gruppentyp-Dokumentation nötig ist; aktuell existiert dafür keine eigene `dpsg-org-hierarchie`-Spec.

## Priorität 2: Sync-Tests ausbauen

Ziel: Die Sync-Kette bleibt automatisiert abgesichert. Offline-Konflikt, Telefonnummer mit Server-Validierungsfehler, Auto-Sync mit WLAN, mobilen Daten und Backoff sowie die ungültige Sitzung laufen als Tests in [test/pending_sync_chain_test.dart](../test/pending_sync_chain_test.dart) und [test/pending_sync_coordinator_test.dart](../test/pending_sync_coordinator_test.dart).

Nächste Aufgaben:

- Kategorien für neue Kontaktangaben senden: Hitobito verlangt seit hitobito#4359 bei Telefonnummern, Zusatzmails und Zusatzadressen eine `category_id`. Ohne sie endet jede Neuanlage aus der App mit 422 („Kategorie muss ausgefüllt werden“). Umsetzbar, sobald [hitobito#4535](https://github.com/hitobito/hitobito/pull/4535) mit `GET /api/contact_account_categories` auf der Instanz läuft: Kategorien laden, beim Anlegen mitsenden, in der UI auswählbar machen, `specs/hitobito_dpsg_openapi.yaml` aktualisieren.
- Den Inhaltsabgleich neuer Telefonnummern in `MemberConflictResolver` formatunabhängig machen. Hitobito liefert Nummern formatiert (`+49 (0170) 123-4567`), die App sendet sie als Ziffernfolge. Kam ein erstes Senden an, galt aber als fehlgeschlagen, legt das erneute Senden die Nummer doppelt an.
- Das Öffnen und Lösen des Problemlösungsfalls im Problemlösungs-Screen an die Ketten-Szenarien anschließen.
- Die übrigen duplizierten Test-Fakes (Logger, App-Settings, Auth, Pending- und Write-Repositories in etwa 15 Testdateien) auf `test/support/` umstellen.
- Contract-Tests gegen einen lokalen Hitobito-Stack mit DPSG-Wagon prüfen: Service-Ebene in Dart mit Service-Token (`X-TOKEN`) statt Geräte-Integrationstests. Hürden sind der Port 3000, den auch der Statistikserver nutzt, eine Dev-Ausnahme für Cleartext-HTTP und der interaktive Login.

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

## Priorität 5: Stammstatistik nachschärfen

Ziel: Die neue Kachel-Statistik nach den ersten Rückmeldungen abrunden.

Nächste Aufgaben:

- Größere Schrift feinschleifen: Bei hoher Textskalierung wirkt die Schrift in einigen Kacheln eher kleiner und der Leerraum wächst (siehe Entwürfe Runde 5 unter `design/statistik/`).
- „Hinter den Kacheln“ aus Runde 2 (§6) als eigene Ausbaustufe konzipieren: Detailseiten beim Antippen der Kacheln.
- Konfession aus echten Daten statt der bisherigen Beispielquelle anzeigen, sobald Hitobito sie liefert.

## Priorität 6: App-Wartung und nützliche Ergänzungen

- GitHub-Pages-Wiki/Userguide für Konfliktlösung, Datenspeicherung und Löschung schreiben.
- Problemlösungs-Screen prüfen: Bereich "Mitglied bearbeiten" bleibt beim Einstieg eingeklappt, kann aber gut sichtbar aufgeklappt werden.
- Erstes Laden: Skeleton oder gleichwertige Fortschrittsanzeige prüfen.
- Erststart nach Update von Versionen vor 1.0.0: alten Datenstand vollständig entfernen und App neu initialisieren, wenn die alte Datenstruktur nicht kompatibel ist.

## Spätere Ausbaustufen

Gesammelt am 2026-10-01, jeweils mit Kurzbefund. Jede Stufe wird vor der Umsetzung eigens geplant.

**Sync weiter beschleunigen**

- Messung vom 2026-10-02 auf dpsg.puzzle.ch im Simulator, Stamm mit 27 Mitgliedern:

  | Stand | Pull-to-Refresh |
  |---|---|
  | Ausgangsstand: Seiten zu 20, ohne Sortierung, alle 404 lesbaren Personen | 30–32 s, 48 Requests |
  | `page[size]=1000` und `sort=id` | 11–12 s |
  | zusätzlich serverseitig auf den Layer gefiltert | 3–4 s |

- Seit dem Filter fragt die App Personen und Rollen nur noch für den aktiven Layer ab, mit `filter[group_id]`, `filter[primary_group_id]`, `filter[id]` und `filter[person_id]`. ID-Listen gehen in parallelen Blöcken zu je 200 raus.
- Der größte Stamm hat ca. 377 Mitglieder, bei etwa 25 ms Serverzeit pro Person sind das 2 parallele Blöcke. Dort noch einmal messen.
- Weiterer möglicher Schritt: `fields[people]` auf die Attribute beschränken, die die App nutzt. So entfallen z. B. die Bankdaten und je nach Bedarf `picture`, das pro Person eine URL berechnet.
- Delta-Sync, Befunde zur API (Hitobito-Core):
  - Hitobito bietet keine globale Version und kein ETag, nur `filter[updated_at]` auf `people`, `roles` und `groups`.
  - Ändern sich Telefonnummern, Zusatzmails oder Zusatzadressen, ändert sich das `updated_at` der Person nicht.
  - Gelöschte Rollen (paranoid) und Personen, die aus der Sichtbarkeit herausfallen, liefert kein Filter.
  - Verlässlich wäre nur ein Manifest-Abgleich: IDs und `updated_at` per `fields[people]`/`fields[roles]` laden, neue oder geänderte Personen per `filter[id]` nachholen, fehlende IDs entfernen. Dazu bräuchte es weiterhin einen periodischen Vollsync für die Kontaktdaten.

**Statistik klickbar („Hinter den Kacheln“)**

- Erster Schritt: Ein Tipp auf eine Kachel öffnet die gefilterte Mitgliederliste.
  - Heute ist das Antippen nur für eigene Kacheln verdrahtet, in `lib/presentation/statistics/kachel_raster.dart`.
- Danach Detailseiten nach `design/statistik/entwurf-runde-2.html` §6.

**Qualifikationen: Erinnerungen**

- `/api/qualifications` ist angebunden und offline verfügbar (Mitgliedsdetails, siehe `specs/mitgliedsdetails-redesign.md`).
- Umgesetzt: konfigurierbare Übersicht über alle Qualifikationen mit Erinnerungen, siehe `specs/qualifikationen-uebersicht.md`.
- Offen:
  - Tippen auf eine Mitteilung soll die passende Seite öffnen. Deep-Links gibt es dafür noch nicht.
  - Die echten Labels für Prävention und Erste Hilfe auf dpsg.puzzle.ch prüfen (`QualifikationsVorgaben`).
  - `DataExpiryNotificationService.initialize()` fragt bei jedem Start um Berechtigung, auch wenn nichts geplant wird.
- Die DPSG-API erlaubt auch POST auf `qualifications`.

**Mitgliedsdetails: offene Punkte**

- Auf dpsg.puzzle.ch bestätigt (2026-10-02): `/api/qualifications` liefert Daten, Rollen tragen über `include=group,layer_group` Gruppe und Layer, `household_key` verknüpft Haushalte.
- Noch prüfen: Lässt sich `fields[people]` ohne Bankfelder nutzen, damit sie gar nicht erst geladen werden?
- Vergangene Rollen: Die API liefert beendete Rollen derzeit nicht. Verlauf und Zeitstrahl sind darauf vorbereitet und markieren die Zeit vor der ersten bekannten Rolle. Zu klären ist, ob `filter[end_on]` oder ein Upstream-PR einen Abruf ermöglicht.
- Store-Screenshots der Szene `Store/Mitgliedsdetail` neu erzeugen.

**Events und Kurse aus Sicht der Teilnehmenden**

- Ziel: Events und Kurse über mehrere Layer und Gruppen hinweg suchen und filtern, sich anmelden und angemeldete Termine in den Kalender übernehmen.
- Befunde zur API (`specs/hitobito_dpsg_openapi.yaml`):
  - `events`, `event_kinds` und `event_participations` sind nur lesbar.
  - Eine Anmeldung per API gibt es nicht. Möglich wären ein Deep-Link auf die Eventseite, `external_application_link` oder ein Upstream-PR für `POST event_participations`.
  - Zum Filtern gibt es `filter[group_id]` als Liste, dazu Art, Kategorie, Typ, `after_or_on` und `before_or_on`.
  - Einen Filter über Layer oder rekursiv gibt es nicht.
  - Bei Kursen lassen sich freie Plätze aus `maximum_participants - participant_count` berechnen.
  - „Meine Anmeldungen“ geht über `event_participations` mit `filter[participant_id]`, das gibt es nur in der DPSG-Spec.
  - Die API bietet keinen iCal-Feed. Die App müsste Einträge selbst im Gerätekalender anlegen.
- Der Scope `api` sollte reichen. Prüfen gegen `dpsg.puzzle.ch`.
- Erster Schritt: ein Spike, wie viele Events mit echten Daten gepflegt sind und in welcher Qualität.
- Trägt das Feature, kommt es ins Supporter-Paket, ohne neue Preisstufe.

**Monetarisierung**

- Ein einziges Supporter-Paket mit Paletten, Icons und Badge. Später kommen gegebenenfalls Events und NaMi AI hinzu.
- Eine Store-Anbindung (`in_app_purchase` oder RevenueCat) ersetzt `UnlockedSupportAccess`.
- Den Erfolg „Unterstützung“ einblenden.
- Vorher den rechtlichen Rahmen klären.

**NaMi AI**

- Zuerst die Eval auf einem echten Gerät abschließen (`chat_ai/eval/manual-test-todo.md`) und BM25 gegen Hybrid entscheiden.
- Danach Android ermöglichen. Heute liegt die gesamte KI-Logik in Swift (`ios/NamiAiKit`), und das Gate in Dart schließt Android aus (`nami_ai_access_service.dart`).
- Empfehlung:
  - Die modellunabhängige Logik nach Dart portieren: BM25 mit Stemming, Grounding-Gate, Schreibabsicht-Filter, Sliding Window, Self-Correction-Policy, Prompts.
  - Je Plattform nur einen schmalen nativen Modell-Adapter vorsehen, auf Android z. B. Gemini Nano.
  - Das Retrieval vor dem Modellaufruf ausführen statt als Tool.

**Mitglied anlegen und Beitrittsanfragen**

- Die DPSG-API bietet POST für `people` und `groups/{id}/self_registrations`.
- Offen sind die Schreibrechte bei Teilsicht, die Offline-Queue und `require_person_add_requests`.

**Spätere Versionen oder ganz streichen**

- Abos/Mailinglisten, Rechnungen und die Events-Verwaltungssicht.
- Die Platzhalter für Abos und Rechnungen in `lib/presentation/screens/settings_page.dart` entfernen.

**Vor dem Livegang (Q1/2027, Version bleibt 1.0.0)**

- `feature/member-edit-felder` mergen, sobald der Hitobito-PR mit den Label-IDs durch ist.
- Den 1.0.0-Eintrag in `assets/changelog.json` auf den tatsächlichen Umfang bringen.
- `README.md` korrigieren: „Mitglieder erstellen“ beschreibt den Altstand.
- Crash-Reporting entscheiden.

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
- [ ] Gültige Adresse offline gespeichert und später erfolgreich synchronisiert.
- [ ] Ungültige Adresse offline gespeichert und später als Problemlösungsfall geprüft.
