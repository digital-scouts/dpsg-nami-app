# Todos

Diese Liste führt nur offene Aufgaben. Umgesetzte Arbeitskontext-, Stufen-, Beitragsart-, Statistik- und Sync-Pakete bleiben im Code, in Tests und im Arbeitskontext-Konzept nachvollziehbar, werden hier aber nicht mehr als aktive Aufgaben geführt.

## Priorität 1: Feldtests und Doku-Abgleich

Ziel: Die bereits implementierten Stammstatistik-, Stufen-, Beitragsart- und Sync-Anpassungen mit echten Daten prüfen und die Projektdokumentation auf den aktuellen Stand bringen.

Nächste Aufgaben:

- Feldtests mit echten Layerdaten durchführen, insbesondere sehr große Stämme, unvollständige Adressen und reale Biber-/Wö-/Jufi-/Pfadi-/Rover-Gruppen.
- Statistiktexte und Lokalisierung für neue oder seltene Statusfälle prüfen und bei Bedarf nachschärfen.
- [specs/hitobito-arbeitskontext-konzept.md](hitobito-arbeitskontext-konzept.md) mit dem umgesetzten Stand zu Stufen, Beitragsarten, Rollenladen und Sync-Status abgleichen.
- Prüfen, ob zusätzliche Begriffs- oder Gruppentyp-Dokumentation nötig ist; aktuell existiert dafür keine eigene `dpsg-org-hierarchie`-Spec.

## Priorität 2: Offline-Sync und Problemlösungsfälle fertig prüfen

Ziel: Der bestehende Problemlösungsfall soll für spätere Sync- und Retry-Situationen belastbar sein.

Nächste Aufgaben:

- Offline-Konflikt manuell testen: Mitglied lokal ändern, Serverstand ändern, später synchronisieren, Problemlösungsfall öffnen und lösen.
- Fehlerhafte Telefonnummer offline speichern und später synchronisieren: Server-Validierungsfehler muss als Problemlösungsfall sichtbar werden.
- Automatischen Sync während aktiver App-Nutzung mit Queue-Einträgen prüfen: WLAN, erlaubte mobile Daten, gedrosselte Retry-Versuche.
- Verhalten bei ungültiger Sitzung erneut prüfen: Hinweis nur einmal anzeigen, Bearbeiten weiterhin wie im Offline-Modus möglich.

## Priorität 3: Adressvalidierung anschließen

Ziel: Adressprobleme aus Offline-Bearbeitung und späterem Sync sollen denselben Problemlösungsfall nutzen wie Konflikte und andere fachliche Sync-Probleme.

Nächste Aufgaben:

- Produktionspfad für Adressvalidierung definieren: wann wird geprüft, wann wird nur gespeichert, wann entsteht ein Problemlösungsfall.
- Geoapify-basierte Prüfung für spätere Retry-/Sync-Fälle anbinden, ohne den normalen Offline-Speicherpfad zu blockieren.
- Ungültige Adresse offline speichern und später synchronisieren: Adresse nicht gefunden oder semantisch unplausibel muss als Problemlösungsfall erscheinen.
- Gültige Adresse offline bearbeiten und später synchronisieren: Änderung muss ohne unnötigen Problemlösungsfall gesendet werden.

## Priorität 4: Adressbearbeitung vereinfachen

Ziel: Die spätere automatische Adressvervollständigung soll den Online-Bearbeiten-Pfad vereinfachen, ohne den Offline-Fallback zu verlieren.

Nächste Aufgaben:

- Adresssuche über den bestehenden Geoapify-Dienst als primären Online-Pfad konzipieren.
- Adresseingabe auf ein Such- und Auswahlfeld reduzieren; Bezeichnung und c/o bleiben eigene Felder.
- Land als Dropdown vorbereiten: Deutschland als Default plus Nachbarländer.
- Aktuelle strukturierte Adresseingabe als Fallback erhalten, wenn offline oder Geoapify nicht verfügbar ist.
- Prüfen, ob das Postfach-Feld im neuen Online-Pfad entfallen kann und wie bestehende Daten weiter angezeigt werden.

## Priorität 5: App-Wartung und nützliche Ergänzungen

- GitHub-Pages-Wiki/Userguide für Konfliktlösung, Datenspeicherung und Löschung schreiben.
- Problemlösungs-Screen prüfen: Bereich "Mitglied bearbeiten" bleibt beim Einstieg eingeklappt, kann aber gut sichtbar aufgeklappt werden.
- Erstes Laden: Skeleton oder gleichwertige Fortschrittsanzeige prüfen.
- Erststart nach Update von Versionen vor 1.0.0: alten Datenstand vollständig entfernen und App neu initialisieren, wenn die alte Datenstruktur nicht kompatibel ist.

## Später prüfen: Arbeitskontext-Ausbau

Diese Punkte sind für den aktuellen MVP nicht blockierend, bleiben aber als spätere Produktentscheidungen relevant.

- Schreib- und Bearbeitungslogik für teilweise sichtbare Layer klären, sobald Gruppenwechsel, Rollenwechsel, Verschieben oder Neuanlage von Personen geplant werden.
- Offene API-Felder prüfen, wenn sie fachlich gebraucht werden: insbesondere Person-`created_at` und mögliche Tags. Rollen-`created_at`, `start_on` und `end_on` sind bereits im Roles-Modell berücksichtigt.
- Mehrere offline verfügbare Arbeitskontexte nur dann konzipieren, wenn ein konkreter Bedarf für parallele Offline-Layer entsteht.
- Rekursive Sichten über Unterlayer nur als eigenen Produktentscheid behandeln; sie gehören weiterhin nicht automatisch zum aktiven Arbeitskontext.
- Persönliche Teilmengen, Tags und "Meine Gruppe" erst nach Stabilisierung der bestehenden Gruppen- und Stufenfilter konkretisieren.

## Manuelle Prüfliste

- [ ] Neue Testdaten enthalten Biber, Wö, Jufi, Pfadi und Rover mit bestätigten Gruppentypen.
- [ ] Stufenfilter zeigt mit neuen Testdaten alle erwarteten Stufen korrekt an.
- [ ] Biber wird über die zentrale Stufenableitung erkannt und bei fehlendem Biber im aktiven Stamm standardmäßig ausgeblendet.
- [ ] Jufi und Pfadi werden fachlich korrekt getrennt.
- [ ] Mitglieder ohne Stufenzuordnung landen weiterhin in Rest beziehungsweise Alle anderen.
- [ ] Konfliktlösung offline getestet.
- [ ] Fehlerhafte Telefonnummer offline gespeichert und später als Problemlösungsfall geprüft.
- [ ] Gültige Adresse offline gespeichert und später erfolgreich synchronisiert.
- [ ] Ungültige Adresse offline gespeichert und später als Problemlösungsfall geprüft.
- [ ] Automatischer Sync mit vorhandenen Queue-Einträgen geprüft.
