# Impressum, Datenschutz, Einwilligungen und Willkommen

- **Datum:** 2026-10-07
- **Runden:** 3
- **Anlass:** Zwei Platzhalterseiten für Impressum und Datenschutz, fehlendes Opt-in, plattformgerechte Bewertungswege, Hinweis im Wiredash-Screenshot, Einwilligung Bundesstatistik, sichtbare Kartenquellen.
- **Umsetzung:**
  - `settings_rechtliches_page.dart`
  - `welcome_dialog.dart` (Stepper)
  - `bundesstatistik_einwilligung_dialog.dart`
  - `bundesvergleich_page.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Einstieg | E2 | Link „Impressum & Datenschutz“ im Fußbereich der Einstellungen, kein eigener Abschnitt |
| Seite | D2 mit „Kurz gesagt“ aus D3, Anbieter darin (S2) | Eine Karte mit Kernaussagen und Anbieter oben, dann Empfänger als Kacheln mit Kurzzweck und „wann“. Details im Sheet, Gerät, Rechte und Quellen als Unterseiten. |
| Willkommen | WS2 · Vollbild-Stepper | Segmentbalken, „Schritt x von n“, großer Titel, Knöpfe unten in voller Breite. Nicht wegtippbar. |
| Schritte | App schützen, Benachrichtigungen, Einstellungen, Highlights | Ohne Biometrie entfällt Schritt 1. „Aktivieren“-Knopf statt Schalter, danach „Aktiv“ mit Haken. Die iOS-Abfrage kommt erst nach dem Knopf. |
| „Warum“-Punkte | A · Liste über der Karte | Gründe stehen offen da, bevor man entscheidet |
| iOS-Feedbackdialog | I1 | Nur „Später“ und „Feedback geben“, ohne „App bewerten“ |
| iOS-Systemdialog | I2 | Nach dem Speichern einer bearbeiteten oder angelegten Person, nach der Bestätigung |
| Abzeichen „App bewertet“ (iOS) | A1 | Öffnet direkt den App Store |
| Abzeichen „Mitgestalten“ | antippbar | Öffnet auf beiden Plattformen das Feedback |
| Android-Dialog | G2 · Knöpfe gestapelt | „App bewerten“ zuerst, öffnet das In-App-Review. Kein Abzeichen „App bewertet“. |
| Screenshot-Hinweis Wiredash | T3 | Umformuliert: nennt „Namen oder Kontaktdaten“ und verweist auf den Stift |
| Einwilligung Bundesstatistik | B2 · Gestuft | Drei Kernaussagen, „Mehr erfahren“ klappt den Rest auf |
| Transparenzkarte | K2 · ID im Kasten | Installations-ID mit „Kopieren“ und Hinweis für Auskunft und Löschung |
| Kartenquelle | Q2 · unten links, halbtransparent | Zentrieren-Knopf bleibt unverändert |

Zusätzliche Vorgaben:

- Schritt 3 heißt „Einstellungen“ und bietet auch die Darstellung.
- Schritt 4 zeigt Highlights statt der Frage nach einer Einführung.
- Akzentfläche wie im Entwurf statt des DPSG-Rots der Tonal-Vorgabe.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Einstieg | E1 · Eigener Abschnitt | nicht gewählt |
| Seite | D1 · Aufklappbare Empfänger, D3 allein, S1 · Kurz gesagt und Anbieter getrennt | nicht gewählt |
| Willkommen | W1 · Dialog, W2 · Bottom-Sheet, WS1 · Dialog fester Höhe | nicht gewählt |
| „Warum“-Punkte | B · Aufklappbare Info-Box | nicht gewählt |
| Abzeichen | A2 · erst Detail-Sheet | nicht gewählt |
| Android | G1 · Drei Knöpfe in einer Reihe | nicht gewählt |
| Screenshot-Hinweis | T1 · Satz angehängt | nicht gewählt |
| Screenshot-Hinweis | T2 · eigene Hinweiszeile | mit Wiredash nicht machbar, nur Texte |
| Einwilligung | B1 · Alles auf einen Blick | nicht gewählt |
| Transparenzkarte | K1 · ID als Zeile | nicht gewählt |
| Kartenquelle | Q1 · unten rechts, Q3 · unter der Karte | nicht gewählt |

## Offen

- nichts
