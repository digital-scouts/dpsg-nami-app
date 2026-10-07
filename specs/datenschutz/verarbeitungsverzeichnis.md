# Verzeichnis der Verarbeitungstätigkeiten (Art. 30 DSGVO)

Stand: 2026-10-07. Gilt für die NaMi-App und den Statistikserver.

Das Verzeichnis erfasst nur Verarbeitungen, über die der Betreiber selbst entscheidet. Mitgliederdaten aus Hitobito verarbeitet die App ausschließlich auf dem Gerät der angemeldeten Leitenden; dafür ist die DPSG nach dem KDG verantwortlich. Ob und wie der Betreiber dabei eingebunden ist, wird mit der DPSG geklärt (siehe `anfrage-dpsg.md`, Befund A-84). Mit `[prüfen]` markierte Angaben muss der Betreiber vor dem Livegang bestätigen.

## Verantwortlicher

Janneck Lange, privat, `dev@jannecklange.de`. Es gibt keinen Datenschutzbeauftragten, weil keine Benennungspflicht besteht (Art. 37 DSGVO, § 38 BDSG).

## V1: Bundesweite Statistik (Statistikserver)

| Feld | Inhalt |
|---|---|
| Zweck | Bundesweiter Vergleich von Gruppengrößen für teilnehmende Stämme; Monatsbericht für den Betreiber |
| Rechtsgrundlage | Einwilligung je Stamm in der App (Art. 6 Abs. 1 lit. a); Betrieb und Missbrauchsschutz (Rate-Limit) auf berechtigtem Interesse (lit. f) |
| Betroffene | Nutzende der App (über die Installation); Mitglieder nur als Zählwerte ohne Personenbezug |
| Daten | Installations-ID (nur als HMAC-Pseudonym gespeichert) und Hash des Installations-Secrets; Stamm- und Gruppen-Pseudonyme; Bezirks- und Diözesennummer im Klartext; Zählwerte je Gruppe nach Geschlecht, Leitende nach Altersgruppen; Zeitpunkte von Datenstand, Versand und Eingang. Die IP-Adresse wird nur flüchtig für das Rate-Limit genutzt und nicht protokolliert. |
| Empfänger | Hoster des vServers: ZAP-Hosting `[prüfen: Firma, Rechenzentrum in Deutschland, AV-Vertrag]`; Telegram (Monatsbericht nur mit Zählwerten, an den Betreiber) |
| Drittland | Keins für die Rohdaten. Telegram `[prüfen]`, enthält aber nur Zählwerte. |
| Löschfrist | Rohsnapshots 14 Monate nach Eingang, Sender 14 Monate nach der letzten Sendung (TTL-Index); vorher auf Anfrage. Backups 14 Tage. Monatsberichte ohne Stamm- oder Senderbezug ohne Frist. |
| TOM | HMAC-Pseudonymisierung mit Secret nur auf dem Host; TLS über Caddy; MongoDB ohne veröffentlichte Ports; Admin-Seite mit Basic Auth und Rate-Limit; Leseberechtigung nur für aktive Teilnehmende; Mindestanzahl Stämme vor Auswertung (`MIN_STAMM_COUNT_FOR_READ`) |

## V2: Feedback, Zufriedenheitsumfrage und Nutzungsanalyse (Wiredash)

| Feld | Inhalt |
|---|---|
| Zweck | Fehler und Wünsche erfahren, App verbessern |
| Rechtsgrundlage | Feedback und Umfrage: Handlung der Nutzenden, berechtigtes Interesse (lit. f). Technischer Ping des SDK: berechtigtes Interesse (lit. f, § 25 Abs. 2 TDDDG `[prüfen]`). Nutzungsereignisse und Fehlerberichte: Einwilligung (lit. a, § 25 Abs. 1 TDDDG), Vorgabe aus. |
| Betroffene | Nutzende; bei Screenshots auch Mitglieder, die darauf zu sehen sind |
| Daten | Ping: App-Nutzungs-ID des SDK, App-Version und Build, Bundle-ID, Betriebssystem und Version, Sprache. Feedback: Text, optional E-Mail und Screenshots, Gerätemetadaten. Ereignisse: Ereignisname, Layer-IDs und -Namen, Fehlertexte, Stacktraces. |
| Empfänger | Wiredash GmbH, Hosting auf Google Cloud Platform; AV-Vertrag in den Projekteinstellungen von Wiredash `[prüfen: abgeschlossen?]` |
| Drittland | USA möglich (Google Cloud), laut Datenschutzerklärung von Wiredash |
| Löschfrist | Nach den Vorgaben von Wiredash `[prüfen]`; Feedback löscht der Betreiber nach Bearbeitung `[festlegen]` |
| TOM | Ereignisse nur mit Opt-in; Hinweis im Screenshot-Schritt, keine Mitgliederdaten aufzunehmen; Wiredash setzt keine Nutzer-ID oder E-Mail von sich aus |

## V3: Geokodierung von Adressen (Geoapify)

| Feld | Inhalt |
|---|---|
| Zweck | Kartenansicht der Mitgliedsadresse, Stammadresse und Standorte-Kachel der Statistik |
| Rechtsgrundlage | Für den Betreiber berechtigtes Interesse (lit. f) an der Bereitstellung der Funktion; die Übermittlung der Mitgliederadressen durch Leitende hängt an der Rollenklärung mit der DPSG (A-84) |
| Betroffene | Mitglieder, überwiegend Minderjährige; Nutzende (IP-Adresse) |
| Daten | Adresstext ohne Namen, IP-Adresse des Geräts, API-Schlüssel des Betreibers |
| Empfänger | Geoapify `[prüfen: Geoapify GmbH, Sitz, AV-Vertrag]` |
| Drittland | `[prüfen]` |
| Löschfrist | Ergebnisse nur auf dem Gerät gespeichert, beim Abmelden gelöscht; bei Geoapify nach deren Bedingungen `[prüfen]` |
| TOM | Nur Adresstext; Ergebnis-Cache auf dem Gerät reduziert Wiederholungen; Netzwerkrichtlinie (WLAN/mobile Daten) für Detailkarten |

## V4: Kartenkacheln (MapTiler bzw. OpenStreetMap)

| Feld | Inhalt |
|---|---|
| Zweck | Kartendarstellung |
| Rechtsgrundlage | Berechtigtes Interesse (lit. f) |
| Betroffene | Nutzende |
| Daten | IP-Adresse, angefragte Kachel (lässt den Kartenausschnitt erkennen), App-Kennung im User-Agent |
| Empfänger | MapTiler AG, Schweiz (Angemessenheitsbeschluss) bzw. OpenStreetMap Foundation, Vereinigtes Königreich (Angemessenheitsbeschluss), je nach Konfiguration |
| Löschfrist | Nach den Bedingungen der Anbieter; Kachel-Cache auf dem Gerät, beim Abmelden gelöscht |
| TOM | Keine Mitgliederdaten in der Anfrage außer dem Kartenausschnitt |

## V5: Update-Hinweis und Mitteilungen (GitHub)

| Feld | Inhalt |
|---|---|
| Zweck | Hinweis auf neue App-Versionen und wichtige Mitteilungen |
| Rechtsgrundlage | Berechtigtes Interesse (lit. f) |
| Daten | IP-Adresse, Zeitpunkt (Abruf einer statischen Datei) |
| Empfänger | GitHub Inc., USA (EU-US Data Privacy Framework) |
| Löschfrist | Nach den Bedingungen von GitHub |

## V6: Stammeskarte (DPSG-Stammessuche)

| Feld | Inhalt |
|---|---|
| Zweck | Karte aller Stämme |
| Rechtsgrundlage | Berechtigtes Interesse (lit. f) |
| Daten | IP-Adresse, Zeitpunkt |
| Empfänger | DPSG, `tools.dpsg.de` |

## V7: Fehlerberichte per Mail und Anfragen Betroffener

| Feld | Inhalt |
|---|---|
| Zweck | Fehleranalyse auf Wunsch der Nutzenden; Bearbeitung von Auskunfts- und Löschanfragen |
| Rechtsgrundlage | Handlung der Nutzenden, berechtigtes Interesse (lit. f); rechtliche Verpflichtung (lit. c) bei Betroffenenanfragen |
| Daten | Mailadresse, Inhalt der Mail, angehängte App- und Traffic-Logs (Methode, Status, Quelle, URI ohne Inhalte), Installations-ID |
| Empfänger | Mailanbieter des Betreibers `[prüfen]` |
| Löschfrist | Logs nach Abschluss der Analyse, Anfragen drei Jahre nach Abschluss (Nachweis) `[festlegen]` |

## Allgemeine TOM der App

- Mitgliederdaten liegen verschlüsselt auf dem Gerät (Hive-Boxen mit Schlüssel im Keychain bzw. Keystore, nur dieses Gerät) und werden beim Abmelden gelöscht.
- Optionale App-Sperre per Face ID oder Fingerabdruck.
- Traffic-Log nur mit Methode, Status, Quelle und URI, ohne Inhalte; Logs werden nach sieben Tagen gelöscht.
