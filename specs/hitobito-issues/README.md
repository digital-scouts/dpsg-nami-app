# Hitobito-Issues

Upstream-Issues für hitobito/hitobito, die die App braucht. Jede Datei ist ein Issue-Text nach der Vorlage `feature.md` von hitobito. Eingereichte Issues bekommen oben die Nummer.

**Grundsatz für alle API-Wünsche:** Funktionsumfang und Rechte sind mit der Weboberfläche identisch oder geringer. Alles läuft über bestehende Funktionen, Abilities und Domain-Klassen des Cores. Es gibt keine neuen Rechte und keine Daten, die das UI der Person nicht zeigt.

| # | Thema | Datei | Stand |
|---|---|---|---|
| 1 | Teilnahmen aus Sicht der Teilnehmenden lesen | `01-teilnahmen-lesen.md` | eingereicht: hitobito#4563 |
| 2 | An Events und Kursen anmelden und abmelden | `02-anmelden-abmelden.md` | eingereicht: hitobito#4564 |
| 3 | Teilnehmende verwalten (Veranstaltende) | `03-teilnehmende-verwalten.md` | Entwurf |
| 4 | Events anlegen, bearbeiten und löschen | `04-events-bearbeiten.md` | Entwurf |

Die Reihenfolge ist zugleich die Abhängigkeit: Issue 1 führt die Ressourcen `event_applications`, `event_answers` und `event_questions` ein, auf denen 2 bis 4 aufbauen.

Weitere offene Upstream-Themen der App: hitobito#4535 (Kontaktkategorien), #4555 und #4556 (Rollen mit Leserecht), #4536 (Rollen nach Zeitraum).
