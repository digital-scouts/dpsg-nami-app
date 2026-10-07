# DSFA-Schwellwertprüfung (Art. 35 DSGVO)

Stand: 2026-10-07. Geprüft wird nach den neun Kriterien der Leitlinie WP 248 rev. 01. Ab zwei erfüllten Kriterien ist eine Datenschutz-Folgenabschätzung in der Regel geboten. Die Verarbeitungen stehen in `verarbeitungsverzeichnis.md`.

## Ergebnis

| Verarbeitung | Erfüllte Kriterien | Ergebnis |
|---|---|---|
| V1 Bundesweite Statistik | keins (pseudonyme Zählwerte, Einwilligung, Frist 14 Monate) | keine DSFA nötig |
| V2 Wiredash | 7 nur bei Screenshots mit Mitgliederdaten, durch Hinweis gemindert | keine DSFA nötig |
| V3 Geokodierung | 5 (große Zahl von Adressen über viele Stämme) und 7 (überwiegend Minderjährige) | **Grenzfall, DSFA empfohlen** |
| V4–V7 | keins | keine DSFA nötig |

Für die Verarbeitung in der App selbst (Mitgliederdaten auf dem Gerät) liegt die Pflicht bei der DPSG als Verantwortlicher. Das Ergebnis gilt deshalb vorbehaltlich der Rollenklärung (A-84).

## Kriterien im Einzelnen

1. **Bewerten oder Einstufen:** nein. Die Statistik vergleicht Gruppengrößen, sie bewertet keine Personen.
2. **Automatisierte Entscheidung mit Rechtswirkung:** nein.
3. **Systematische Überwachung:** nein. Nutzungsereignisse gibt es nur mit Einwilligung, sie sind pseudonym.
4. **Sensible oder höchstpersönliche Daten:** nein. Die App speichert nur das Datum der Einsichtnahme in das erweiterte Führungszeugnis, nicht dessen Inhalt; es bleibt auf dem Gerät und geht an keinen Dienst des Betreibers.
5. **Umfangreiche Verarbeitung:** bei V3 ja. Die Standorte-Kachel ist in der Standardbelegung und geokodiert die Hauptadressen aller sichtbaren Mitglieder, über alle Stämme mit App-Nutzung. Bei V1 nein, weil nur Zählwerte ankommen.
6. **Abgleichen oder Zusammenführen von Datensätzen:** nein.
7. **Schutzbedürftige Betroffene:** bei V3 ja, die Mitglieder sind überwiegend Kinder und Jugendliche. Bei V2 nur, wenn Nutzende Screenshots mit Mitgliederdaten anhängen.
8. **Innovative Technologie:** nein.
9. **Hindert Betroffene an der Ausübung von Rechten:** nein.

## Empfehlung zu V3

Zwei Kriterien sind formal erfüllt. Für die Risiken sprechen die mildernden Umstände: Geoapify erhält nur den Adresstext ohne Namen, die Ergebnisse bleiben auf dem Gerät, und es gibt keine Verknüpfung mit weiteren Merkmalen. Möglich sind zwei Wege:

- eine kurze DSFA für V3 erstellen, oder
- das Risiko so senken, dass die Schwelle nicht mehr erreicht wird, z. B. die Standorte-Kachel aus der Standardbelegung nehmen oder vor der ersten Auflösung einen Hinweis zeigen.

Die Entscheidung trifft der Betreiber, sinnvollerweise nach der Antwort der DPSG zur Rollenklärung.
