# Kurse & Veranstaltungen

Stand: 2026-10-10, erster Durchgang umgesetzt (#211). Der Bereich sucht Kurse und Veranstaltungen aus Hitobito, zeigt sie an, übernimmt Termine in den Gerätekalender und öffnet die Eventseite im Web. Eine Anmeldung in der App gibt es noch nicht. Die Gestaltung steht in `design/entscheidung/2026-10-10-kurse-veranstaltungen.md`.

Es werden nur Konzepte aus dem Hitobito-Core genutzt, nichts aus den Wagons `hitobito_pfadi_de` oder `hitobito_dpsg`.

## Fachbegriffe im Hitobito-Core

- **Veranstaltung (`Event`):** allgemeiner Termin einer oder mehrerer Gruppen, z. B. Lager, Aktion oder Versammlung. Wer sich anmeldet, nimmt sofort teil.
- **Kurs (`Event::Course`):** der einzige Untertyp im Core.
  - Hat eine Kursart (`Event::Kind`) mit Kategorie (`Event::KindCategory`), Mindestalter, allgemeinen Infos und Anmeldebedingungen. Kursarten vergeben Qualifikationen und können welche voraussetzen (`Event::KindQualificationKind`).
  - Eine Anmeldung ist zuerst eine Bewerbung (`Event::Application`). Sie bleibt offen, bis die Kursleitung einen Platz vergibt. Dazu kommen Prioritäten, Warteliste und optional eine Freigabe durch die eigene Ebene.
  - Am Ende markiert die Leitung „qualifiziert“.
- **Für beide:** ein oder mehrere Termine (`Event::Date`), ein Anmeldefenster (`application_opening_at`, `application_closing_at` als Kalendertage), Fragen bei der Anmeldung (`Event::Question`) und eine Abmeldung, wenn `applications_cancelable` gesetzt ist und der Anmeldeschluss noch nicht vorbei ist.
- Wagons können weitere Typen ergänzen. Die App behandelt alles außer `Event::Course` als Veranstaltung.

## API-Befunde

Geprüft am Hitobito-Core (`upstream/master`, Stand 2026-10-08) und am lokalen dpsg-stack (Core `0eff728f6`).

- **Nur lesend:** `events`, `event_kinds`, `event_kind_categories` und `event_participations` bieten ausschließlich `index` und `show`.
- **Sichtbarkeit:** `/api/events` liefert serverseitig alles, was die Person sehen darf (`EventReadables`):
  - Events der eigenen Ebenen
  - global sichtbare Events (`globally_visible`, Standard an)
  - Events mit externer Anmeldung
  - eigene Teilnahmen
  - Ebenen darunter bei `layer_and_below_*`
  Damit funktioniert die Suche über Ebenen ohne rekursiven Filter. Ohne aktive Rolle liefert Hitobito nichts.
- **JSON:API-Typen:** Kurse kommen als `courses`, einfache Events als `events` mit `type: null`. Sparse Fields müssen deshalb für beide Typen gesetzt werden (`fields[events]`, `fields[courses]`). Termine heißen `dates`, die Leitung kommt als `person-name`.
- **Includes:** `dates`, `kind.kind_category`, `contact` und `leaders` funktionieren.
- **Belegung:** `participant_count` und `applicant_count` gibt es nur bei Kursen.
- **Externe Anmeldung:** `external_application_link` gibt es nur, wenn `external_applications` gesetzt ist.
- **Nicht in der API:**
  - `applications_cancelable`, `waiting_list`, `requires_approval`, `participations_visible` und „Anmeldung möglich“
  - Anmeldefragen
  - die Qualifikationen, die eine Kursart vergibt
- **„Meine Teilnahmen“:** `/api/event_participations?filter[participant_id]=…` ist Core, seit 2026-03 (hitobito#3789). `specs/hitobito_openapi.yaml` ist an dieser Stelle veraltet. Die Ressource liefert nur aktive Teilnahmen; offene Kursbewerbungen fehlen, auch die eigenen.
- **Scopes:** `api` reicht. Daneben kennt Hitobito die Scopes `events` und `event_participations`.
- **Alte JSON-API:** Sie konnte ebenfalls nicht anmelden, und Schreiben scheitert am CSRF-Schutz. Sie lieferte aber mehr Lesedaten:
  - `participant_count`, `state` und `teamer_count` für alle Events
  - Tags und Anhänge
  - Antworten auf Anmeldefragen
  Sie wird nicht weiterentwickelt (hitobito#3726).
- **Kalender:** Hitobito hat einen persönlichen iCal-Feed (`/event_feed.ics?token=…`). Das Token ist aber nur über die Weboberfläche erreichbar.

### Abgleich gegen den lokalen Stack

Testdaten: Seed aus `mvpfad/dpsg-stack#1` mit 10 Szenarien über Stamm, Bezirk, Diözese und Bund. Ergebnisse aus Sicht des Mitglieds ohne Rechte (`mitglied@example.com`):

- Die Liste zeigt die eigenen Events, die anderer Stämme mit `globally_visible` sowie alle Kurse von Bezirk, Diözese und Bund.
- Nicht global sichtbare Events fremder Stämme fehlen; `show` liefert dafür 403.
- Vergangene Events entfallen durch `filter[after_or_on]`.
- `filter[participant_id]` liefert die aktive Teilnahme am Lager, aber nicht die offene Bewerbung für den Bezirkskurs.
- Gruppennamen sind über `/api/groups?filter[id]=…` auch ohne Rechte lesbar.

Ein Spike zur Datenqualität mit echten Daten folgt nach dem Livegang. Vorher gibt es auf `dpsg.puzzle.ch` keine gepflegten Events.

## Umgesetztes Verhalten

- **Einstieg:**
  - Der Eintrag „Kurse & Veranstaltungen“ im Schnellzugriff der Einstellungen ersetzt den bisherigen Platzhalter.
  - Ab 840 pt steht er zusätzlich in der Seitenleiste.
  - Kein fünfter Tab, keine Supporter-Schranke.
- **Laden:**
  - `HitobitoEventsService` fragt `/api/events` nur auf Abruf ab, nicht im Hintergrund-Sync.
  - Abgefragt werden Events ab heute, mit Terminen und Kursart.
  - Die Ergebnisse hält `VeranstaltungenModel` je Ebene 15 Minuten im Speicher. Nichts davon wird auf dem Gerät gespeichert.
  - Ein Sitzungswechsel (Abmelden, anderes Konto) verwirft alles.
  - Unbekannte Gruppennamen lädt das Modell gesammelt über `/api/groups` nach.
- **Ebene:** Die Ebene bestimmt die Anfrage. Die anderen Filter wirken lokal auf die geladenen Events.
  - „Eigene Ebene“: aktiver Layer und seine Gruppen.
  - „Eigene Ebene und darüber“: zusätzlich die Gruppen der Layer darüber.
  - „Alle sichtbaren“ (Standard): ohne `filter[group_id]`.
- **Lokale Filter:** Art, Kursart-Kategorie, Zeitraum, „Anmeldung offen“ und Freitext. Der Freitext sucht in Name, Motto, Ort, Terminorten, veranstaltender Gruppe und Kursart. Sortiert wird nach dem ersten Termin.
- **Anmeldestatus** (`BestimmeAnmeldestatusUseCase`):
  - offen, bis einschließlich Schlusstag
  - öffnet am …
  - Anmeldeschluss vorbei
  - keine Angaben
  - freie Plätze nur bei bekanntem Maximum und bekannter Belegung
- **Detail:**
  - Lädt Beschreibung, Anmeldebedingungen, Kontakt, Leitung und Kursart-Infos nach.
  - „Zur Anmeldung“ öffnet die öffentliche Anmeldeseite, wenn das Event externe Anmeldungen erlaubt.
  - Sonst öffnet „Im Web öffnen“ die Eventseite in Hitobito (`/groups/:g/events/:e`, Login im Browser).
  - Im Demo gibt es keinen Web-Link.
- **Kalender:**
  - `add_2_calendar` öffnet den Systemdialog mit vorausgefülltem Termin.
  - Bei mehreren Terminen wird vorher gefragt, welcher eingetragen wird.
  - Ab iOS 17 ist keine Kalenderberechtigung nötig; für iOS 16 steht `NSCalendarsUsageDescription` in der `Info.plist`.
  - Android nutzt einen Intent und braucht keine Berechtigung.
- **Zustände:** offline, Anmeldung nötig, Fehler, keine sichtbaren Events (ohne Rolle), keine Treffer für die Filter.
- **Datenschutz:** Angezeigt werden Name von Kontakt- und Leitungspersonen, nichts darüber hinaus. Die Kalenderübernahme erfolgt nur auf Nutzeraktion über den Systemdialog.

## Offene Punkte

- **Last (#189):** Bei „Alle sichtbaren“ lädt die App alle kommenden Events der Instanz, die die Person sieht. Bei bundesweit global sichtbaren Events können das viele sein. Seitengröße und Cache-Dauer nach dem Livegang mit echten Daten prüfen; falls nötig den Standard auf „Eigene Ebene und darüber“ oder einen begrenzten Zeitraum setzen.
- **Folgeschritte:**
  - „Meine Termine“ über `filter[participant_id]` im Sync-Schritt `nav_work_context_step_veranstaltungen`, in einer verschlüsselten Box.
  - Erinnerungen an Anmeldeschluss und Beginn.
  - Native Anmeldung und Abmeldung nach den Upstream-Änderungen unten.
  - Kurs-Admin-Ansicht.

## Upstream-Issues (hitobito/hitobito)

Die App braucht für die nächsten Schritte Erweiterungen der JSON:API. Die Texte stehen in `specs/hitobito-issues/`. Grundsatz: Funktionsumfang und Rechte sind mit der Weboberfläche identisch oder geringer und laufen über bestehende Core-Funktionen.

1. Teilnahmen aus Sicht der Teilnehmenden lesen: eingereicht als hitobito#4563.
2. An Events und Kursen anmelden und abmelden: eingereicht als hitobito#4564.
3. Teilnehmende verwalten (Veranstaltende): Entwurf.
4. Events anlegen, bearbeiten und löschen: Entwurf.
