# Mitgliedsdetails: Bedarfsanalyse und Redesign

Stand: 2026-10-02, umgesetzt. Diese Spec beschreibt die Ausgangslage der Mitgliedsdetailseite, die festgelegten Anforderungen, die Edge Cases und den umgesetzten Stand. Die freigegebenen visuellen Entwürfe liegen unter `design/mitglied/` (Runden 1 bis 5).

## Umgesetzter Stand

**Kopf:** `MemberSteckbriefKopf`, eine Zeile ohne eigene AppBar (Runde 5, K2)
- Zurück, Avatar, Name bzw. Fahrtenname mit vollem Namen und der Zeile „30 Jahre · sie/ihr · weiblich“. Jede Zeile ist einzeilig und endet bei Überlänge mit „…“. Ein Tipp auf den Namen klappt alle Zeilen vollständig auf, ein zweiter wieder zu.
- Aktive Stufenrollen als überlappende runde Icons rechts neben dem Namen, Leitung zuerst: Maskottchen für Mitgliedschaft, Lilie in Stufenfarbe für Leitung. Ab vier Stufen fasst „+n“ den Rest zusammen. Die Beschriftung („Wö-Leitung“) steht im Tooltip. Ein Tipp auf die Icons öffnet den Rollen-Tab. Ohne Stufenrolle erscheint die Lilie für „Sonstige“.
- Bearbeiten als Stift rechts in derselben Zeile.
- Die Tabs sind so breit wie ihr Text und zentriert, bei großer Schrift scrollbar statt abgeschnitten. Sie behalten ihren Zustand.

**Daten:** `MemberDetails`
- **Kacheln:** Geburtstag und Mitgliedsdauer. Der Geburtstag ist heute rot getönt mit Kuchen, in 1–7 Tagen blau getönt.
- **Familie:** Chips aus dem Hitobito-Haushalt.
- **Kontakt und Adressen:** weitere Telefonnummern, E-Mails und Zusatzadressen eingeklappt.
- **Details:** Mitgliedsnummer, Beitragsart, Stamm und Gruppe. Die Konfession entfällt, bis Hitobito sie liefert.
- **Karte:** Ist sie nicht verfügbar, erscheint eine flache Hinweisfläche mit Aktion („Erneut versuchen“, „In Karten-App öffnen“). Beim Laden steht kein Fehlertext mehr.

**Rollen:** `MemberRollenTab`
- **Kennzahlen:** Dauer, Leitungsjahre und durchlaufene Stufen.
  - Kinder ohne Leitung sehen statt der Leitungsjahre den nächsten Stufenwechsel (`berechneNaechstenStufenwechsel`): „jetzt“ (überfällig), „ab JJJJ“ (noch nicht möglich), „bis JJJJ“ (jetzt möglich, spätestens dann).
  - Maßgeblich ist die höchste aktive Mitgliedsstufe, mit den eingestellten Altersgrenzen und dem Stichtag. Rover sehen das Ende der Roverzeit.
- **Bahnen:** Mitglied, Leitung und Ämter auf einer Jahresachse (`VerlaufBahnen`).
  - Kürzel stehen nur im Balken, wenn sie passen.
  - Die Zeit vor der ersten bekannten Rolle ist schraffiert.
- **Zeitstrahl:** `MemberRollenZeitstrahl`
  - Rollen nach Beginnjahr, aktive Rollen getönt, Geplantes oben, mehr als fünf Jahre eingeklappt.
  - Rollen anderer Layer sind standardmäßig ausgeblendet, ein Hinweis am Ende blendet sie ein.

**Qualifikationen:** `MemberQualifikationenTab`
- **EFZ-Zeile:** Statuspunkt mit „Keines hinterlegt“, „Gültig bis …“, „noch 7 Wochen“ oder „Abgelaufen am …“. Dazu die Zustände „noch nicht synchronisiert“ und „keine Berechtigung“.
- **Download:** runder Knopf ohne Text, entfällt ohne Berechtigung.
- **Qualifikationen:** im gleichen Stil, abgelaufene gedämpft am Ende.

**Daten und Sync:**
- Bankdaten werden nicht übernommen und nicht gespeichert.
- `household_key` wird übernommen.
- Rollen tragen `groupName` und `layerName`.
- EFZ und Qualifikationen werden beim Sync parallel geladen und mit `TeildatenStand` im verschlüsselten Arbeitskontext gespeichert. Ein 403 gilt als fehlende Berechtigung. Bei Fehlschlag bleibt der zuletzt geladene Bestand erhalten.

**Absicherung:**
- **Stories:** Personen aus `lib/stories/support/mitglied_edge_cases.dart`, also Funke, Mats, Jonas, Sami, Petra und Karl.
- **Tests:** mit festem Stichtag.

## Ausgangslage vor dem Redesign

Der Screen `lib/presentation/screens/member_detail_page.dart` besteht aus einem Kopf und drei Tabs: Daten, Rollen und Qualifikationen.

- **Kopf:** Zurück-Pfeil, Initialen-Avatar, Fahrtenname bzw. Name. Daneben ein Stufen-Badge nach `MemberUtils.visualRole` oder „Sonstige“ und das Symbol für ausstehende Änderungen. Bei ausstehenden Änderungen erscheint ein `MaterialBanner`.

### Daten

Die Abschnitte stehen in `member_basis.dart` und `member_basis_info_card.dart`:

- **Persönliche Daten:** Alter mit Geburtstag, Geschlecht, Pronomen. Dazu Konfession mit dem Platzhalter `'Geplant (Dummy)'`.
- **Kontakt:** alle Telefonnummern und E-Mails, immer ausgeklappt.
- **Adresse:** nur die Hauptadresse. Darunter eine Kartenvorschau mit 186 px Höhe (`address_map_preview.dart`).
- **Mitgliedschaft:** Mitgliedsnummer, Eintritt, letzte Änderung, Status, Beitragsart, Stamm und Gruppe.

Befunde:

- **Kartenfehler:** Technischer Fehler, Timeout und fehlender API-Key zeigen dieselbe Meldung „Karte nicht verfügbar – Technischer Fehler“ auf voller Höhe, ohne Möglichkeit zum erneuten Versuch.
- **Laden der Karte:** Schon beim Laden steht „Karte nicht verfügbar“ auf dem Skelett (`skeletton_map.dart`).
- **Fehlende Daten:** Zusatzadressen, Austrittsdatum und Haushalt werden nicht angezeigt.
- **Neuladen:** Die Tabs halten ihren Zustand nicht. Karte und EFZ laden bei jedem Tabwechsel neu.

### Rollen

Die Liste steht in `member_roles_list.dart` und `member_roles_list_tile.dart`. Sie ist nach Start sortiert und in die Abschnitte Zukünftig, Aktiv und Abgeschlossen geteilt. Rollen vom Typ `Group::Mitglieder::*` sind ausgeblendet.

Befunde:

- **Gruppe und Layer fehlen:** Die Rollen kommen aus allen sichtbaren Layern (`hitobito_roles_service.dart` hat keinen Active- oder Layer-Filter). Gruppennamen kennt die App aber nur für den aktiven Layer.
- **Platzbedarf:** Das Stufenbild ist 80×80 px groß, eine Rolle belegt damit fast 100 px Höhe.
- **Wischen ohne Funktion:** Jede Zeile lässt sich wischen und zeigt einen Löschen-Hintergrund, es passiert aber nichts.
- **Vergangene Rollen:** Beendete Rollen liefert die API derzeit nicht. Die OpenAPI-Spec bietet nur `filter[end_on]` und `filter[active][eq]=<Datum>`, dazu gibt es keine verlässliche Aussage.

### Qualifikationen

Hier steht nur das EFZ (`efz_status_section.dart`): ein zentrierter Block mit Symbol, Titel, Status-Badge, Gültigkeit, Hinweistext und Download-Knopf.

Befunde:

- **Laden:** Das EFZ wird bei jedem Öffnen live geladen. Es gibt keinen Offline-Cache, offline erscheint ein Fehler.
- **Falsche Meldung:** Ohne Session oder ohne `personId` steht „Fehlt / Keine Einsichtnahme hinterlegt“, obwohl nichts geladen wurde.
- **Fehlende Rechte:** Fehlt das EFZ-Recht (`:group_and_below_efz`), endet der Abruf mit 403 und zeigt nur den allgemeinen Fehler.
- **Nicht angebunden:** `/api/qualifications` fehlt noch.

## Festgelegte Anforderungen

- **EFZ:**
  - Bleibt im Qualifikationen-Tab, als kompakte Zeile bei jedem Mitglied, ohne Unterscheidung nach Pflicht.
  - Zustände: „keines hinterlegt“, die Daten der Einsichtnahme, „läuft bald ab“.
  - Der Download der Antragsunterlagen bleibt.
- **Qualifikationen:** `/api/qualifications` wird angebunden. Qualifikationen und EFZ werden beim Layer-Sync für alle sichtbaren Personen geladen und im verschlüsselten Arbeitskontext-Cache gespeichert.
- **Bankdaten:** Kontoinhaber, IBAN, BIC, Bank und Zahlungsart werden nicht angezeigt und nicht gespeichert, möglichst auch nicht geladen.
- **Daten:**
  - Zusätzlich anzeigen: Zusatzadressen, Austritt bzw. Mitgliedsdauer und Haushalt.
  - Weitere Adressen, E-Mails und Telefonnummern sind eingeklappt, damit nicht alles sofort sichtbar ist.
- **Kartenfehler:** Ein technischer Kartenfehler darf den Bereich nicht in voller Größe belegen.
- **Rollen:**
  - Design und Stories sind schon auf vergangene Rollen ausgelegt.
  - Dazu kommt eine Statistik zum bisherigen Pfadfinder-Verlauf.

## Datenquellen

| Feld | Quelle (`specs/hitobito_dpsg_openapi.yaml`) | Stand | Ziel |
|---|---|---|---|
| Hauptadresse | `people` Adressfelder | angezeigt | bleibt |
| Zusatzadressen | `additional_addresses` (include) | geladen, nicht angezeigt | eingeklappt anzeigen |
| Weitere E-Mails, Telefon | `additional_emails`, `phone_numbers` | angezeigt | ab dem zweiten Eintrag eingeklappt |
| Austritt | `people.exit_date` | geladen, nicht angezeigt | anzeigen, dazu die Mitgliedsdauer |
| Haushalt | `people.household_key` (readOnly) | nicht geladen | laden; Familie aus sichtbaren Personen mit gleichem Schlüssel |
| Bankdaten | `bank_account_owner`, `iban`, `bic`, `bank_name`, `payment_method` | geladen und gecacht | entfernen, `fields[people]` als Whitelist |
| Rollengruppe, Layer | `roles` mit `include=group,layer_group` | nur `group_id` | Name von Gruppe und Layer an der Rolle cachen |
| Qualifikationen | `GET /api/qualifications`, `include=qualification_kind` | nicht angebunden | beim Sync laden und cachen |
| Qualifikationsart | `qualification_kinds`: `label`, `validity`, `reactivateable` | – | nur über include, kein eigener Pfad |
| EFZ | `GET /api/efz_einsichtnahmen` (nicht in der Spec) | live je Person | beim Sync laden und cachen, 403 als „keine Berechtigung“ |
| Konfession | – | Dummy | Entscheidung in den Entwürfen |

Bei Qualifikationen lässt sich nur nach `person_id` und `qualification_kind_id` filtern, sortieren nur nach `id`. Es gibt kein `PUT`. `membership_number` liest der Code, die Spec führt das Feld aber nicht. Eine `fields[people]`-Whitelist muss deshalb vorab gegen die echte Instanz geprüft werden.

## Edge Cases

Diese Fälle tragen die Entwurfspersonen in `design/mitglied/daten.js` und später die Stories und Tests.

**Rollen und Verlauf:**

- **Neuling:** Eine Wölflings-Rolle seit letzter Woche, kein Verlauf, keine Qualifikationen.
- **Vielrolle:** Mehr als 15 Rollen über 20 Jahre, davon mehrere gleichzeitig aktiv.
- **Mehrlayer:**
  - Leitung im Stamm, dazu Bezirks- und Diözesanrollen.
  - Für die Gruppen außerhalb des aktiven Layers fehlt bisher der Name.
- **Parallele Stufen als Mitglied:** Jungpfadfinder und Pfadfinder gleichzeitig während des Stufenwechsels.
- **Leitung in mehreren Stufen parallel:** z. B. Wölflings- und Rover-Leitung.
- **Gemischt:** Ein Rover leitet zugleich die Wölflinge.
- **Nur Sonstiges:** Stammeskassierer*in bzw. Vorstand ohne Stufe.
- **Zukünftige Rolle:** Der Stufenwechsel ist bereits angelegt.
- **Rolle ohne Startdatum:** Als Ersatz dient `created_at` bzw. das Eintrittsdatum.
- **Ausgetreten:** Es gibt nur noch vergangene Rollen.

**Daten:**

- **Adresse:** Keine Adresse, oder die Adresse wird nicht gefunden.
- **Kontakt:** Fünf Telefonnummern und drei E-Mails, zwei Zusatzadressen (z. B. bei getrennt lebenden Eltern).
- **Kartenfehler:** technischer Fehler, Timeout bzw. fehlender API-Key, offline, nur WLAN erlaubt.
- **Familie:** Drei Geschwister in einem Haushalt. Ein Familienmitglied liegt außerhalb der Sicht und wird nicht angezeigt.
- **Unbekannte Daten:** Der Geburtstag fehlt (Platzhalter 1900-01-01).

**Qualifikationen:**

- **EFZ-Zustände:** keines hinterlegt, gültig, läuft bald ab (90 Tage), abgelaufen.
- **Nicht geladen:** Das EFZ ist noch nicht synchronisiert bzw. offline ohne Cache.
- **Keine Berechtigung:** keine EFZ-Berechtigung (403).
- **Gültigkeit:** Qualifikationen ohne Ablauf (`validity` leer), abgelaufene und reaktivierbare.
