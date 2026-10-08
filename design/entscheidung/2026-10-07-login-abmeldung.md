# Hinweis nach Abmeldung wegen fehlender Rechte

- **Datum:** 2026-10-07
- **Runden:** 1
- **Anlass:** Hat das Konto keinen lesbaren Stamm, Bezirk und keine lesbare Gruppe mehr, meldet die App ab und löscht die Daten. Danach erfuhr man nicht, warum.
- **Umsetzung:** `lib/presentation/widgets/abmeldung_hinweis_karte.dart`, Texte `auth_logout_rights_changed_*`

Das Ergebnis ist aus der Umsetzung abgeleitet.

## Entschieden

| Frage | Ergebnis | Kurz beschrieben |
|---|---|---|
| Darstellung | B · Info-Karte über dem Login-Button | Ruhige Karte in Primärfarbe mit Titel „Rechte geändert“ und zwei Sätzen. Titel und Text des Login-Bildschirms bleiben. |
| Dauer | bis zum nächsten Login | Die Karte bleibt auch nach einem Neustart der App sichtbar. |

## Abgelehnt

| Frage | Variante | Grund |
|---|---|---|
| Darstellung | A · Rote Fehlerzeile | laut Entwurf wirkt sie wie ein technischer Fehler |
| Darstellung | C · Einmaliger Dialog | laut Entwurf nach dem Schließen nicht mehr nachlesbar |
| Darstellung | D · Eigener Titel und Text | nicht gewählt |

## Offen

- nichts
