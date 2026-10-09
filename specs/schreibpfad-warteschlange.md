# Schreibpfad und Warteschlange

Stand: 2026-10-09. Wie Änderungen an Mitgliedern nach Hitobito gelangen und was mit ihnen passiert, wenn das nicht sofort klappt (#190). Gestaltung: `design/entscheidung/2026-10-09-schreibpfad-sicherheitsupdate.md`.

## Speichern

- Vor dem ersten Senden wird die Änderung als Eintrag `person-<id>` vorgemerkt (`MemberEditModel.submitUpdate`). Endet die App während des Requests, ist sie nicht verloren.
- Erfolg entfernt den Eintrag. Ausgänge, die die Änderung verwerfen (Ablehnung, Konflikt ohne Merge, fehlendes `updated_at`, Validierung ohne Problemfall), stellen den Stand vor dem Speichern wieder her.
- Kein Netz, Netz gesperrt, Anmeldung nötig oder unbekannter Fehler: Der Eintrag bleibt vorgemerkt und wird nachgesendet.
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
