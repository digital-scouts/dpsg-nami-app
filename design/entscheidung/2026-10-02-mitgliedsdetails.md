# Mitgliedsdetails

- **Datum:** 2026-10-02
- **Runden:** 5
- **Anlass:** Neuer Aufbau der Mitgliedsdetailseite mit Daten, Rollen, Verlauf und Qualifikationen. Edge Cases stehen in `specs/mitgliedsdetails-redesign.md`.
- **Umsetzung:**
  - PR #170
  - `MemberSteckbriefKopf`, `MemberDetails`, `MemberRollenTab`, `MemberQualifikationenTab`
  - Spec „Umgesetzter Stand“

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Struktur | S2 · Steckbrief-Kopf mit Tabs | Kopf mit Avatar, Name bzw. Fahrtenname und der Zeile „30 Jahre · sie/ihr · weiblich“, kein EFZ-Chip. Darunter die Tabs Daten, Rollen, Qualifikationen. |
| Kopf-Anordnung | K2 · Eine Zeile | Zurück, Avatar, Name und Bearbeiten in einer Zeile ohne eigene AppBar. Aktive Stufenrollen als überlappende runde Icons rechts neben dem Namen: Lilie in Stufenfarbe für Leitung, Maskottchen für Mitgliedschaft. Ein Tipp führt zum Rollen-Tab. |
| Tab „Qualifikationen“ | B · Breite nach Text | Tabs so breit wie ihr Text, zentriert, bei großer Schrift scrollbar statt abgeschnitten |
| Schnellaktionen im Kopf | nein | laut Umsetzung nicht im Kopf |
| Einklappen beim Scrollen | nein | laut Umsetzung nicht umgesetzt |
| Daten | D3 · Kennzahlen zuerst | Kacheln Geburtstag und „dabei seit“, Familie als Chips, dann Kontakt und Adresse. Weitere Einträge eingeklappt, der Rest unter „Details“. |
| Geburtstag hervorheben | G1 mit Kuchen | Am Tag selbst rot getönt mit Kuchen, in 1–7 Tagen blau getönt, ab dem 8. Tag normal. Bis 31 Tage vorher zählt die Kachel die Tage, sonst die Monate. |
| Kartenfehler | M3 · Flache Karte | Flache Hinweisfläche mit Aktion. Beim Laden steht kein Fehlertext. |
| Rollen | R3 · Zeitstrahl mit H1 | Rollen nach Beginnjahr auf einer Linie, aktive Rollen auf getöntem Grund |
| Layer-Filter | F2 · Hinweis am Ende | Standard „nur aktiver Layer“, am Ende „n ausgeblendet · Anzeigen“ |
| Verlauf | K2 · Kacheln frei, Bahnen darunter | Kennzahlen als eigene Kacheln, darunter die Stufenbahnen. Kürzel entfallen bei Platzmangel. Kinder ohne Leitung sehen statt „in der Leitung“ den nächsten Stufenwechsel. |
| Qualifikationen | E2 · Punkt mit Link-Zeile | EFZ als kompakte Zeile ohne „ausgestellt“ und „eingesehen“, runder Download-Knopf ohne Text. „Abgelaufen am …“ als eigener roter Zustand. |

Zusätzliche Vorgaben:

- Bankdaten erscheinen nirgends und werden nicht mehr gespeichert.
- Konfession bleibt ausgeblendet, bis Hitobito sie liefert.
- Qualifikationen und EFZ sind nach dem Sync offline verfügbar.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Struktur | S1 · Tabs wie heute, S3 · Eine Seite mit Sprungmarken | nicht gewählt |
| Kopf | K1 · Name in der AppBar mit Chips darunter, mit oder ohne Schnellaktionen | nicht gewählt |
| Tabs | A · Kurzlabel „Quali“, C · weniger Innenabstand | nicht gewählt |
| Daten | D1 · Karten wie heute, D2 · Liste mit Symbolen | nicht gewählt |
| Geburtstag | G2 · Kuchen und blaue Unterzeile ohne Tönung | nicht gewählt |
| Kartenfehler | M1 · Schmale Zeile, M2 · Hinweis in der Adresszeile | nicht gewählt |
| Rollen | R1 · Nach Status, R2 · Nach Layer | nicht gewählt |
| Hervorhebung | H2 · Gefüllter Punkt, H3 · Block „Jetzt“ | nicht gewählt |
| Layer-Filter | F1 · Umschalter oben | nicht gewählt |
| Verlauf | K1 · Eine Karte | nicht gewählt |

## Offen

- nichts
