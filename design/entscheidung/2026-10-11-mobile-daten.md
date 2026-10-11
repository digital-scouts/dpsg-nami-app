# Mobile Daten einschränken

- **Datum:** 2026-10-11
- **Runden:** 1
- **Anlass:** Der Schalter „Mobile Daten einschränken“ war falsch beschrieben und wurde nicht überall angewendet (#204). Selbst angestoßene Ladevorgänge sollen nach Bestätigung über mobile Daten laufen dürfen.
- **Umsetzung:** Branch `fix/mobile-daten-204`; `settings_app_page.dart`, `settings_map_page.dart`, `statistics_ui.dart`, `address_map_preview.dart`, `settings_stamm_address.dart`, `veranstaltungen_page.dart`, `member_edit_page.dart`

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Schalter | S1: Kurz, gekürzt | Titel „Mobile Daten einschränken“, Untertitel „Schränkt mobilen Datenverbrauch ein“. |
| Karte und Adresse | L1: Hinweis auf der Karte | Die Karte zeigt nur gespeicherte Kartenteile. Unten auf der Karte liegt eine Hinweiskarte „Karte nur aus dem Speicher“ mit dem Knopf „Über mobile Daten laden“. Bei der Adresssuche steht ein Hinweis „Vorschläge im WLAN“ unter dem Feld, mit dem Knopf „Vorschläge über mobile Daten laden“. Die Bestätigung gilt, bis man die Seite verlässt. |
| Veranstaltungen | V1: Zwei Knöpfe | Eigener Zustand „Nur im WLAN“ mit Erklärung, „Trotzdem laden“ als Hauptknopf und „Abbrechen“ als Textknopf, der zurückführt. Echtes Offline behält „Keine Verbindung“. |
| Mitglied senden | M1: Dialog | Nach „Speichern“ fragt ein Dialog „Änderung jetzt senden?“ mit „Später im WLAN“ und „Jetzt senden“ als Hauptaktion. „Später“ legt die Änderung in die Warteschlange, die Meldung lautet „Gespeichert. Die Änderung wird im WLAN gesendet.“ |

Zusätzliche Vorgaben aus den Kommentaren:

- Der Untertitel des Schalters soll so knapp wie möglich sein.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Schalter | Ist, S2, S3 | Ist beschreibt das Verhalten falsch; S2 und S3 zu lang |
| Karte und Adresse | L2, L3 | nicht gewählt |
| Veranstaltungen | Ist, V2 | Ist ist irreführend; V2 nicht gewählt |
| Mitglied senden | M2 | nicht gewählt |

## Offen

- nichts
