# Logs in Debug & Tools

- **Datum:** 2026-10-07
- **Runden:** je 1 (Hitobito-Traffic, App-Logs, Log-Bereich)
- **Anlass:** Traffic- und App-Log waren nur als Rohtext lesbar, Fehler gingen unter. Der Log-Bereich hatte Quelle, Datei und drei Knöpfe.
- **Umsetzung:**
  - `lib/presentation/screens/log_viewer_page.dart`
  - `lib/presentation/widgets/hitobito_traffic_log_view.dart`
  - `lib/presentation/widgets/app_log_view.dart`
  - `_LogEinstiege` in `settings_debug_tools_page.dart`

Das Ergebnis ist aus der Umsetzung abgeleitet, eine Rückmeldung wurde nicht abgelegt.

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Traffic-Ansicht | A · Kompakte Liste | Eine Zeile je Anfrage, Status als farbiges Kennzeichen vorn. Antippen klappt die vollständige URI mit „Kopieren“ auf. Host entfällt, Query entschlüsselt. |
| Lange Feldlisten (fields, include) | eingeklappt | erscheinen erst beim Antippen |
| Traffic-Filter | Alle/Fehler | Chips über der Liste |
| App-Log-Ansicht | C · Terminal, aufgeräumt | Dichte Monospace-Ansicht, neueste oben, Datumstrenner statt Datum je Zeile. Warnungen und Fehler farbig, Stacktraces eingeklappt. |
| App-Log-Filter | Level und „Routine ausblenden“ | Routinezeilen (nav, http) per Chip ausblendbar, beim Öffnen sichtbar |
| key=value-Paare | Text mit grauen Schlüsseln | keine Chips |
| Einstieg in Debug & Tools | E2 · Listenzeilen | zwei Zeilen mit Einträgen und Fehlern von heute |
| Zeitraum | Z2 · ein Chip mit Blatt | Chip „Heute ▾“ öffnet ein Blatt mit Vorlagen und Von–bis |
| Menü | so | Teilen, Report Issue und Löschen. Teilen und Report Issue nehmen den sichtbaren Ausschnitt, Löschen fragt nach und betrifft alle Tage. |

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Traffic-Ansicht | B · nach Läufen gruppiert, C · Tabelle | nicht gewählt |
| App-Log-Ansicht | A · Karten wie beim Traffic, B · Abschnitte nach App-Start und Login | nicht gewählt |
| Einstieg | E1 · Kacheln | nicht gewählt |
| Zeitraum | Z1 · Chip-Reihe | nicht gewählt |

## Offen

- nichts
