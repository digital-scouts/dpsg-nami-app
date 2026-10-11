# Schreibpfad und Warteschlange

Stand: 2026-10-09. Wie Änderungen an Mitgliedern nach Hitobito gelangen und was mit ihnen passiert, wenn das nicht sofort klappt (#190). Gestaltung: `design/entscheidung/2026-10-09-schreibpfad-sicherheitsupdate.md`.

## Speichern

- Vor dem ersten Senden wird die Änderung als Eintrag `person-<id>` vorgemerkt (`MemberEditModel.submitUpdate`). Endet die App während des Requests, ist sie nicht verloren.
- Erfolg entfernt den Eintrag. Ausgänge, die die Änderung verwerfen (Ablehnung, Konflikt ohne Merge, fehlendes `updated_at`, Validierung ohne Problemfall), stellen den Stand vor dem Speichern wieder her.
- Kein Netz, Netz gesperrt, Anmeldung nötig oder unbekannter Fehler: Der Eintrag bleibt vorgemerkt und wird nachgesendet.
- Bei „Mobile Daten einschränken“ ohne WLAN fragt die Seite vorher: „Jetzt senden“ sendet mit Freigabe, „Später im WLAN“ merkt ohne Sendeversuch vor (`vormerkenFuerWlan`). Siehe `specs/mobile-daten.md`.
- Hat ein abgebrochener Versuch einen Kontakt schon angelegt, erkennt der Merge ihn beim erneuten Senden am Inhalt (`MemberConflictResolver`, `sameContent`) und legt ihn nicht doppelt an.

## Nachsenden

`MemberEditModel.retryPending`, automatisch über `PendingSyncCoordinator` oder per „Jetzt senden“.

| Ausgang | Eintrag | Zählt als Versuch |
|---|---|---|
| Erfolg | entfernt | – |
| Kein Netz, Netz gesperrt | bleibt, restliche Einträge werden in diesem Lauf nicht versucht | nein |
| Anmeldung nötig | bleibt, Lauf endet | nein |
| Feldkonflikt, Validierung | Problemfall mit Feldeinträgen | – |
| Ablehnung, Konflikt, fehlendes `updated_at` | Problemfall mit Grund von Hitobito (`MemberResolutionCase.hinweis`), ohne Feldeinträge | – |
| Unbekannter Fehler | bleibt | ja |

- Nach zehn gezählten Versuchen pausiert das automatische Senden für den Eintrag (`PendingRetryPolicy`). „Jetzt senden“ geht weiter.
- Lehnt Hitobito beim automatischen Nachsenden etwas ab, zeigt die App eine Leiste „Hitobito hat eine Änderung an <Name> abgelehnt.“ mit „Anzeigen“. In der Liste steht das Warnsymbol für offene Problemfälle.

## Problemfall und Verwerfen

- Problemfälle löst man im Problemlösungsmodus der Bearbeiten-Seite. Bei einer Ablehnung zeigen Detail-Banner und Problemlösungsmodus den Grund von Hitobito.
- Eine Ablehnung ohne Feldbezug lässt sich korrigieren und neu senden oder im Problemlösungsmodus mit „Änderung verwerfen“ ganz verwerfen.
- Pausierte Einträge lassen sich im Detail-Banner verwerfen.
- Verwerfen wirkt sofort. Eine Leiste bietet „Rückgängig“ an (`discardPending`, `restorePending`).

## Sync-Versuch

- Ein Hitobito-Sync zählt erst als Versuch, wenn Hitobito erreichbar war. Bei gesperrtem Netz, fehlendem Netzzugriff oder Netzfehler wird der vorherige Zeitpunkt wiederhergestellt (`AuthSessionModel._versuchNichtZaehlen`). Der nächste Trigger darf es sofort erneut versuchen.
- `PendingSyncCoordinator` setzt danach den WLAN-Trigger zurück, damit dieselbe Verbindung den Sync erneut auslösen kann.

## Datenablauf

- Ist die Aufbewahrungsfrist überschritten, sendet die App einmal die vorgemerkten Änderungen (`sendeVorgemerkteVorAblauf`, höchstens 20 s), meldet dann ab und löscht die Daten.
- Der Login zeigt die Karte „Daten abgelaufen“. Gingen Änderungen verloren, erscheint sie als Warnung mit der Zahl.
- Läuft der Ablauf schon, warten weitere Auslöser auf ihn. Während des Sendens prüft der Remote-Zugriff die Frist nicht erneut.

## Bearbeiten

- Mit Eingaben seit dem Öffnen fragt die Bearbeiten-Seite beim Zurückgehen (Knopf und Geste) in einem Sheet nach: „Speichern“, „Weiter bearbeiten“, „Verwerfen“. Ohne Änderung geht es ohne Rückfrage zurück.
- Bearbeiten-Felder schalten das Lernen der Tastatur, Autokorrektur und Vorschläge ab. In Suche, Filter, Stammesadresse, KI-Chat, „Problem melden“ und Log-Suche ist nur das Lernen der Tastatur aus (#200).

## Bewusste Entscheidungen

- **Kein Entwurf über Prozessende:** Ungespeicherte Eingaben im Bearbeiten werden nicht gespeichert (Datensparsamkeit). Beim Verlassen mit Änderungen fragt die App nach. Gespeicherte Änderungen bleiben in der Warteschlange.
- **Keine Fristverlängerung für Wartendes:** Beim Datenablauf gibt es genau einen Sendeversuch. Klappt er nicht (etwa weil auch die Anmeldung abgelaufen ist), gehen die Änderungen mit den übrigen Daten verloren. Die Login-Karte nennt die Zahl.
