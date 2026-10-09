# Schreibpfad und Sicherheitsupdate

- **Datum:** 2026-10-09
- **Runden:** 2
- **Anlass:** Neue sichtbare Teile aus #190 (abgelehnte und pausierte Änderungen, Datenablauf, Verlassen des Bearbeitens) und #197 (Sicherheitsupdate mit Sperre).
- **Umsetzung:** PRs zu #190 und #197, siehe dort

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Abgelehnte Änderung | P2 · Problemfall mit Grund | Lehnt Hitobito eine Änderung beim automatischen Nachsenden ab, wird sie ein normaler Problemfall: Warnsymbol in der Liste und im Kopf, Banner „Hitobito hat eine vorgemerkte Änderung abgelehnt …“ mit dem Grund von Hitobito in einer Zeile, Knopf „Problem lösen“ öffnet den bestehenden Problemlösungsmodus. Kein eigener Banner und kein „Erneut senden“, weil ein erneutes Senden bei einer Ablehnung nicht hilft. |
| Pausiertes Nachsenden | Q1 · Senden und Verwerfen | Bestehender Banner nach zehn Fehlversuchen, zusätzlich „Verwerfen“ neben „Jetzt senden“. |
| Verwerfen | V2 · Sofort mit Rückgängig | Kein Dialog. Nach „Verwerfen“ erscheint eine Leiste „Änderung verworfen.“ mit „Rückgängig“. |
| Hinweis nach automatischem Nachsenden | H1 + H2 | Einmalige Leiste „Hitobito hat eine Änderung an <Name> abgelehnt.“ mit „Anzeigen“ (öffnet die Person). Dazu das bestehende Warnsymbol in der Mitgliederliste. |
| Login nach Datenablauf | D2 · Warnkarte bei Verlust | Karte über dem Login-Knopf wie bei „Rechte geändert“. Gingen vorgemerkte Änderungen verloren, in Warnfarbe mit Titel „Daten abgelaufen, N Änderungen verloren“ und der Bitte, sie nach dem Anmelden erneut einzutragen. Sonst ruhige Karte „Daten abgelaufen“. |
| Verlassen des Bearbeitens | R2 · Sheet mit Speichern | Nur bei ungespeicherten Änderungen: Sheet von unten „Nicht gespeicherte Änderungen“ mit „Speichern“ (Hauptaktion), „Weiter bearbeiten“ und „Verwerfen“. Ein Entwurf wird bewusst nicht gespeichert. |
| Sicherheitsupdate | S2 · Sheet von unten, Texte X2 | Titel „Sicherheitsupdate erforderlich“, Satz „In dieser Version steckt eine Sicherheitslücke. Das Update behebt sie.“, Zeile „Betrifft: …“ aus `version.json`, Hinweis „Du kannst es noch N× verschieben, danach sperrt sich die App bis zum Update.“, Knöpfe „Jetzt aktualisieren“ und „In 3 Stunden erinnern“. |
| Nach dem zweiten „Später“ | T1 · Countdown-Banner oben | Statt eines dritten Dialogs ein warnfarbener Streifen oben über jeder Seite: „Sicherheitsupdate nötig – Die App sperrt sich in 2 Std. 45 Min.“ mit „Jetzt aktualisieren“. Läuft die Zeit ab, kommt die Sperre. |
| Sperre | L2 · Sperre mit Notfallzugang | Deckende Fläche wie die App-Sperre (Verlauf, Glasfläche, keine DPSG-Zeichen) mit „Zum Store“, „Notfallkontakte ansehen“ und „Erneut prüfen“. Der Notfallzugang ist eine reine Leseliste mit Namen und Telefonnummern, ohne Bearbeiten und ohne Sync. |

Zusätzliche Vorgaben aus den Kommentaren:

- Je Sicherheitsupdate legt `version.json` fest, ob die Daten beim Sperren bleiben (Standard, mit Notfallzugang) oder gelöscht werden (bei einem Datenleck, dann ohne Notfallzugang und mit Hinweis, dass die Daten zum Schutz gelöscht wurden).
- Normale Updates unter `min_supported` sperren nie, damit z. B. Notfallkontakte erreichbar bleiben.

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Abgelehnte Änderung | A1 · Warnbanner mit „Verwerfen“ / „Erneut senden“, A2 · mit Änderungsliste | Es gibt schon den Problemfall-Weg; bei einer Ablehnung hilft erneutes Senden nicht |
| Abgelehnte Änderung | P1 · bestehender Banner ohne Grund | nicht gewählt |
| Pausiertes Nachsenden | Q2 · nur „Jetzt senden“ | nicht gewählt |
| Verwerfen | V1 · Rückfrage-Dialog | nicht gewählt |
| Hinweis nach Nachsenden | H3 · Mitteilung oben | nicht gewählt |
| Login nach Datenablauf | D1 · immer ruhige Karte | nicht gewählt |
| Verlassen | R1 · Dialog ohne Speichern | nicht gewählt |
| Sicherheitsupdate | S1 · Dialog | nicht gewählt; Texte sollten besser werden |
| Sicherheitsupdate-Texte | X1 · ohne „Betrifft“ | nicht gewählt |
| Nach dem zweiten „Später“ | Ankündigungsdialog „App wird gesperrt“; T2 · Leiste über der Tabbar | durch Countdown-Banner oben ersetzt |
| Sperre | L1 · vollständige Sperre ohne Notfallzugang | Notfallkontakte sollen erreichbar bleiben, solange die Daten nicht gelöscht werden müssen |

## Offen

- nichts
