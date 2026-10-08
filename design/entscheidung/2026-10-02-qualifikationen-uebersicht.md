# Qualifikationen-Übersicht

- **Datum:** 2026-10-02
- **Runden:** 3
- **Anlass:** Die Seite „Qualifikationen“ wird zur Übersicht über alle Qualifikationsarten im Stamm, nach dem Vorbild von Campflow.
- **Umsetzung:**
  - PR #172
  - `lib/presentation/screens/qualifikationen/`
  - `qualifikation_bausteine.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Übersicht | U3 · Zeilen in einer Karte | Eine Zeile je Qualifikation mit schmalem Balken. Grün gültig, orange demnächst fällig, rot fehlt. Fehlt und abgelaufen zählen beide als „fehlt“ und sind im Balken voll rot. |
| Karte geöffnet | D2 · Umschalter „Handlungsbedarf / Alle“ | Zuerst nur, wo etwas zu tun ist. Abgelaufene stehen bei den Fehlenden, behalten aber ihr Label. |
| Personenkreis | P1 · Regeln aus Bausteinen | z. B. „wer Rollenart Leitung“, „oder Rollenart Amt“, „und Alter ab 16“ |
| Weg zu den Einstellungen | Übersicht → Auswahl → Einstellungen | Zahnrad oder „Qualifikation hinzufügen“ öffnen die Auswahl mit Schaltern und Reihenfolge, der Pfeil öffnet die Einstellungen. Aus der geöffneten Karte führt das Zahnrad direkt dorthin. |
| Supporter-Sperre | L2 · nur Hinweis | Gesperrt zeigt die Seite nur einen Hinweis, dazu ein Testschalter in Debug & Tools |
| Eigene Erinnerungen | unter Benachrichtigungen | Schalter, Arten und gemeinsamer Vorlauf, zusätzlich als Meldung in der App. Für alle, auch ohne Supporter. |

Zusätzliche Vorgaben:

- EFZ fest 5 Jahre, nicht einstellbar und ohne Zusatz. Bei Hitobito-Arten steht „aus Hitobito“.
- Erinnerung „Von wem“ statt „An wen“: Erinnert wirst immer du, bei allen im Personenkreis oder nur bei dir.
- Kein Bereich „Früher gesehen“. Sichtbar ist nur, was im Kontext jemand hat. Einstellungen bleiben gespeichert.
- „Aus der Übersicht entfernen“ entfällt, dafür gibt es den Schalter in der Auswahl.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Übersicht | U1 · Karten untereinander (Campflow), U2 · Raster mit zwei Spalten | nicht gewählt |
| Karte geöffnet | D1 · Nach Status gruppiert | nicht gewählt |
| Personenkreis | P2 · Fertige Kreise | nicht gewählt |
| Supporter-Sperre | L1 · Vorschau unscharf | nicht gewählt |
| Balken | Fehlt rot schraffiert | in Runde 3 auf voll rot geändert |

## Offen

- Labels als Personenkreis, sobald die API sie liefert
