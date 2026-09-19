# GitHub-Issue-Backlog für den Server

## Zweck und Zielbild

Dieses Dokument übersetzt das geplante Servervorhaben in kleine, übernehmbare GitHub-Issues. Der Server startet bewusst unter `server/` im selben Repository, damit App und Server fachlich eng beieinander bleiben, aber technisch sauber getrennt aufgebaut werden können.

Zielbild für den MVP ist ein transparenter Statistikserver, der versionierte Stammes-Snapshots annimmt, serverseitig pseudonymisiert verarbeitet, daraus einen aktuellen Stand je Stamm ableitet und ausschließlich materialisierte Bundesaggregate für berechtigte Teilnehmende bereitstellt. Der MVP ist bewusst eine nachvollziehbare Annäherung und keine amtliche Wahrheit.

## Leitplanken und Annahmen

- Der Server startet bewusst unter `server/` im selben Repository.
- Ohne explizite Zustimmung werden keine Stammes-Snapshots gesendet.
- Nur Stämme sind im MVP Datenquelle, keine Bezirke oder Diözesen.
- Im MVP werden nur bundesweite Vergleiche ausgeliefert.
- Der Server speichert ausschließlich klar benennbare Stammes-Metadaten und keine Rohmitgliedsdaten.
- Stamm- und Sender-IDs werden serverseitig pseudonymisiert.
- Bezirk und DV dürfen im MVP im Klartext gespeichert werden.
- Für die Beurteilung der Aktualität eines Snapshots ist `source_data_as_of` maßgeblich; `sent_at` ist nur Tie-Breaker.
- Ein Stamm bleibt nur dann in der Statistik, wenn sein neuester gültiger Snapshot höchstens zwei Monate alt ist.
- Nur aktive Teilnehmende dürfen das Bundesaggregat lesen.
- Die Teilnahme an der Read-API ist nur für Sender zulässig, die in den vergangenen 14 Tagen mindestens einmal erfolgreich gesendet haben.
- Im MVP stoppt ein Widerruf nur weitere Sendungen; historische Daten werden nicht rückwirkend entfernt.
- Im MVP bleibt der Server eine transparente Annäherung und keine amtliche Wahrheit.

## Zielarchitektur und Systemgrenzen

- Der Server wird als Node.js-/TypeScript-Service unter `server/` umgesetzt und per Docker startbar gemacht.
- MongoDB ist im MVP die zentrale Persistenz für historische Snapshots, Current State je Stamm und materialisierte Wochenaggregate.
- Ein Ingest-Endpunkt nimmt versionierte Stammes-Snapshots an und akzeptiert nur definierte Schema-Versionen.
- Der Ingest verarbeitet nur erlaubte Felder und lehnt nicht unterstützte oder fachlich unzulässige Nutzdaten ab.
- Historische Snapshots, Current State pro Stamm und Wochenaggregate werden getrennt gespeichert.
- Die Ableitung des Current State erfolgt pro Stamm genau einmal anhand des neuesten gültigen Snapshots, primär über `source_data_as_of` und nur bei Gleichstand über `sent_at`.
- Die Read-API rechnet nicht live auf Rohsnapshots.
- Die Read-API stellt ausschließlich materialisierte Bundesaggregate bereit.
- Regionale Vergleiche für Bezirk oder DV sind ausdrücklich nicht Teil des MVP.
- Die Tickets sind als vertikale Schnitte formuliert, sodass zuerst ein vollständiger MVP-Pfad von Ingest bis Read entsteht.

## MVP-Tickets

### Ticket 1: Statistikserver: Basisgerüst mit lokalem Host-Start und MongoDB-Compose-Setup aufsetzen

- Titel: Statistikserver: Basisgerüst mit lokalem Host-Start und MongoDB-Compose-Setup aufsetzen
- Typ: Architektur
- Priorität: P0
- Status: erledigt
- Ziel: Einen minimalen, startbaren Serverrahmen mit klarer Struktur schaffen, bei dem der Server lokal direkt auf dem Host laufen kann, während MongoDB per Docker Compose bereitgestellt wird und der Bootpfad eine Datenbankverbindung voraussetzt.
- Kurzbeschreibung: Unter `server/` soll ein Node.js-/TypeScript-Service mit klarer Modulstruktur, Startpunkt, Konfiguration und Docker-Startpfad angelegt werden. Das Basisgerüst soll lokale Entwicklung mit MongoDB über Docker Compose und einem direkt auf dem Host laufenden Server vorbereiten. Zusätzlich soll ein getrennter Compose-Pfad für einen vollständig containerisierten Betrieb von Server und MongoDB vorliegen. Der Server baut beim Start eine MongoDB-Verbindung auf und startet nur erfolgreich, wenn die Datenbank erreichbar ist.
- Akzeptanzkriterien:
  - Unter `server/` existiert ein startbarer Node.js-/TypeScript-Service mit dokumentiertem Einstiegspunkt.
  - Der Service lässt sich lokal direkt auf dem Host starten.
  - MongoDB wird für die lokale Entwicklung per Docker Compose als eigener Dienst bereitgestellt.
  - Der Server baut beim Start eine Verbindung zu MongoDB auf.
  - Wenn MongoDB beim Start nicht erreichbar ist, beendet sich der Server mit nachvollziehbarer Fehlermeldung.
  - Für einen vollständig containerisierten Betrieb existiert ein separater Compose-Pfad für Server und MongoDB.
  - Grundlegende Konfiguration für Umgebung, Logging, Fehlerantworten und MongoDB-Verbindung ist vorhanden.
- Abhängigkeiten: Keine.
- Nicht Teil dieses Tickets: Fachliche Snapshot-Validierung, Pseudonymisierung, finales Dokumentmodell, Aggregationslogik, Read-API, Backup, Replikation, Monitoring und Produktionsbetrieb der Datenbank.

### Ticket 2: Snapshot-Ingest-API für den Statistikserver erstellen

- Titel: Snapshot-Ingest-API für den Statistikserver erstellen
- Typ: Feature
- Priorität: P0
- Status: erledigt
- Ziel: Einen belastbaren Eingangspfad für versionierte Stammes-Snapshots schaffen.
- Kurzbeschreibung: Der Server stellt einen Ingest-Endpunkt bereit, der ausschließlich Stammes-Snapshots annimmt. Der Endpunkt validiert die unterstützte Schema-Version, normalisiert bekannte Felder in das MVP-Schema, verwirft unbekannte Felder rekursiv und liefert für ungültige Nutzlasten strukturierte 400-Fehler ohne Persistenz.
- Akzeptanzkriterien:
  - Der Ingest akzeptiert nur Stammes-Snapshots, keine Bezirks- oder Diözesen-Snapshots.
  - Der Ingest akzeptiert nur die explizit unterstützte Schema-Version `2026-04-01`.
  - Der Ingest erwartet `POST /snapshots/stamm` und liefert bei erfolgreicher Validierung `204 No Content`.
  - Unbekannte Felder werden auf allen Ebenen serverseitig verworfen; fehlende bekannte Kennzahlenfelder werden als `null` normalisiert.
  - Ungültige Anfragen liefern `400` mit strukturierter Fehlerantwort aus Fehlercode, Nachricht und betroffenen Feldpfaden, ohne Persistenz.
- Abhängigkeiten: Ticket 1.
- Nicht Teil dieses Tickets: Pseudonymisierung, Current-State-Ableitung, Aggregation, Read-Berechtigungen.

### Ticket 3: Serverseitige Pseudonymisierung für den Statistikserver

- Titel: Serverseitige Pseudonymisierung für den Statistikserver
- Typ: Feature
- Priorität: P0
- Status: erledigt
- Ziel: Stamm- und Sender-Identitäten serverseitig stabil pseudonymisieren, bevor sie persistiert oder weiterverarbeitet werden.
- Kurzbeschreibung: Der Server überführt eingehende Stamm- und Sender-IDs direkt nach erfolgreicher Snapshot-Validierung serverseitig in stabile Pseudonyme. Der aktuelle Ingest-Pfad arbeitet intern bereits mit pseudonymisierten IDs weiter; Roh-IDs sind damit nicht mehr das interne Übergabeformat für spätere Persistenz- und Ableitungsschritte.
- Akzeptanzkriterien:
  - Stamm- und Sender-IDs werden serverseitig pseudonymisiert.
  - Die Pseudonymisierung ist für identische Eingaben stabil reproduzierbar.
  - Der Ingest-Pfad führt die Pseudonymisierung unmittelbar nach erfolgreicher Validierung aus.
  - Roh-IDs werden nicht als internes Übergabeformat für spätere Persistenz verwendet.
  - Bezirk und DV dürfen im MVP im Klartext erhalten bleiben.
- Abhängigkeiten: Ticket 2.
- Nicht Teil dieses Tickets: Teilnahmeprüfung, Aggregationslogik, Read-API.

### Ticket 4: Rohsnapshots persistieren und Persistenzstruktur vorbereiten

- Titel: Rohsnapshots persistieren und Persistenzstruktur vorbereiten
- Typ: Feature
- Priorität: P0
- Status: erledigt
- Ziel: Den Ingest so absichern, dass gültige Snapshots revisionsfähig in `raw_snapshots` landen und die spätere Weiterverarbeitung strukturell vorbereitet ist.
- Kurzbeschreibung: Nach Validierung und Pseudonymisierung werden eingehende Stammes-Snapshots in `raw_snapshots` persistiert. Zusätzlich werden `effective_states` und `weekly_aggregates` als Collections samt Grundstruktur und benötigten Indizes vorbereitet, in diesem Ticket aber noch nicht befüllt.
- Akzeptanzkriterien:
  - Jeder gültige, pseudonymisierte Stammes-Snapshot wird in `raw_snapshots` persistiert.
  - Persistiert werden nur die vorgesehenen Stammes-Metadaten; Rohmitgliedsdaten werden nicht gespeichert.
  - Für `effective_states` und `weekly_aggregates` existiert eine definierte Collection- und Indexstruktur.
  - `effective_states` und `weekly_aggregates` werden in diesem Ticket weder fachlich abgeleitet noch befüllt.
- Abhängigkeiten: Ticket 3.
- Nicht Teil dieses Tickets: Fachliche Ableitung des effektiven Stammestands, Wochenaggregation, Read-Endpunkte.
- Handoff an Entwicklung:

  #### Empfohlene Einbauorte

  - Persistenz von `raw_snapshots` direkt im erfolgreichen Ingest-Pfad nach Validierung und Pseudonymisierung verankern.
  - Schreiblogik für `raw_snapshots` in ein eigenes Persistenzmodul kapseln, damit Ticket 5 und Ticket 7 darauf aufbauen können.
  - Initiales Anlegen von `effective_states` und `weekly_aggregates` in den MongoDB-Startup- oder Schema-Setup-Pfad legen, nicht in fachliche Ableitungslogik.
  - Basisstruktur der Dokumente für `effective_states` und `weekly_aggregates` jetzt nur als technische Vorbereitung definieren, ohne Schreibaufrufe aus dem Ingest auszulösen.

  #### Empfohlene Indexe

  - Für `raw_snapshots` einen zusammengesetzten Index auf pseudonymisierter Stamm-ID, `source_data_as_of` und `sent_at` vorsehen.
  - Für `raw_snapshots` einen zusätzlichen Index auf `sent_at` vorsehen, damit spätere zeitliche Auswertungen und Rebuilds effizient bleiben.
  - Für `effective_states` bereits einen eindeutigen Index auf pseudonymisierter Stamm-ID anlegen, obwohl die Collection in diesem Ticket leer bleibt.
  - Für `weekly_aggregates` bereits einen eindeutigen Index auf Aggregationswoche und Aggregationstyp anlegen, ohne in diesem Ticket Dokumente zu schreiben.

  #### Testfokus

  - Absichern, dass nur gültige und bereits pseudonymisierte Stammes-Snapshots in `raw_snapshots` landen.
  - Absichern, dass in `raw_snapshots` nur freigegebene Stammes-Metadaten gespeichert werden und keine Rohmitgliedsdaten persistiert werden.
  - Absichern, dass `effective_states` und `weekly_aggregates` samt geplanter Indexe angelegt werden, aber nach dem Ticket leer bleiben.
  - Absichern, dass der Ingest für Ticket 4 keine fachliche Ableitung von `effective_states` und keine Befüllung von `weekly_aggregates` auslöst.

### Ticket 5: Effektiven Stammestand fachlich ableiten

- Titel: Effektiven Stammestand fachlich ableiten
- Typ: Feature
- Priorität: P0
- Status: offen
- Ziel: Pro Stamm genau einen fachlich gültigen effektiven Stand aus den in `raw_snapshots` gespeicherten Snapshots bestimmen und in `effective_states` materialisieren.
- Kurzbeschreibung: Aufbauend auf Ticket 4 wird die fachliche Auswahl des effektiven Stammestands implementiert. Maßgeblich ist zuerst `source_data_as_of`; nur bei Gleichstand entscheidet `sent_at`. Das Ergebnis wird je Stamm in `effective_states` geschrieben.
- Akzeptanzkriterien:
  - Für jeden Stamm existiert nach der Ableitung höchstens ein aktueller Eintrag in `effective_states`.
  - Die Auswahl des effektiven Stammestands nutzt `source_data_as_of` als Primärkriterium.
  - `sent_at` wird nur als Tie-Breaker verwendet.
  - Die Ableitung arbeitet ausschließlich auf `raw_snapshots` und den zulässigen Stammes-Metadaten.
- Abhängigkeiten: Ticket 4.
- Nicht Teil dieses Tickets: Befüllung von `weekly_aggregates`, 14-Tage-Teilnahmeregel, Read-API.
- Handoff an Entwicklung: Fachregel sauber kapseln und idempotent auslegen, damit spätere Rebuilds von `effective_states` aus `raw_snapshots` möglich bleiben.

### Ticket 6: Statistikserver: Teilnahme- und Zugangslogik klären

- Titel: Statistikserver: Teilnahme- und Zugangslogik klären
- Typ: Feature
- Priorität: P0
- Status: offen
- Ziel: Die fachlichen Regeln für Teilnahme am Senden und Berechtigung zum Lesen im Server konsistent abbilden.
- Kurzbeschreibung: Der Server soll unterscheiden zwischen Sendezugang, Teilnahme an der Read-API und Widerruf. Im MVP stoppt ein Widerruf nur weitere Sendungen; historische Daten bleiben erhalten. Zugriff auf die Read-API erhalten nur aktive Teilnehmende, die in den vergangenen 14 Tagen mindestens einmal erfolgreich gesendet haben.
- Akzeptanzkriterien:
  - Die Read-API ist nur für Sender zulässig, die in den vergangenen 14 Tagen mindestens einmal erfolgreich gesendet haben.
  - Nur aktive Teilnehmende dürfen das Bundesaggregat lesen.
  - Ein Widerruf stoppt im MVP weitere Sendungen.
  - Historische Daten werden durch einen Widerruf im MVP nicht rückwirkend entfernt.
- Abhängigkeiten: Ticket 2, Ticket 5.
- Nicht Teil dieses Tickets: Komplexe Rollenmodelle, nachträgliche Datenlöschung, regionale Auswertungen.

### Ticket 7: Wöchentliche Bundesaggregation im Statistikserver einführen

- Titel: Wöchentliche Bundesaggregation im Statistikserver einführen
- Typ: Feature
- Priorität: P1
- Status: offen
- Ziel: Aus dem Current State aller qualifizierten Stämme ein materialisiertes Bundesaggregat pro Woche erzeugen.
- Kurzbeschreibung: Der Server soll aus dem aktuellen Stand je Stamm ein Wochenaggregat bilden. Berücksichtigt wird pro Stamm höchstens ein Snapshot, und ein Stamm fließt nur ein, wenn sein neuester gültiger Snapshot höchstens zwei Monate alt ist.
- Akzeptanzkriterien:
  - Pro Stamm wird höchstens ein Snapshot in die Wochenaggregation übernommen.
  - Ein Stamm bleibt nur im Aggregat, wenn sein neuester gültiger Snapshot höchstens zwei Monate alt ist.
  - Das MVP erzeugt ausschließlich Bundesaggregate und keine regionalen Vergleiche.
  - Die Aggregation basiert auf materialisiertem Current State und nicht auf Live-Abfragen historischer Rohsnapshots.
- Abhängigkeiten: Ticket 5, Ticket 6.
- Nicht Teil dieses Tickets: Bezirks- oder DV-Aggregate, komplexe Mehrsender-Auswahl, Referenzzahlen des Verbands.

### Ticket 8: Statistikserver: Read-API bereitstellen

- Titel: Statistikserver: Read-API bereitstellen
- Typ: Feature
- Priorität: P1
- Status: offen
- Ziel: Eine lesende API für materialisierte Bundesaggregate mit klaren Transparenz-Metadaten bereitstellen.
- Kurzbeschreibung: Die Read-API soll ausschließlich materialisierte Bundesaggregate ausliefern. Sie rechnet nicht live auf Rohsnapshots und gibt neben Statistikwerten die wesentlichen Transparenz-Metadaten zum Datenstand und zur Annäherungslogik zurück.
- Akzeptanzkriterien:
  - Die Read-API liefert nur Bundesaggregate aus.
  - Die Read-API rechnet nicht live auf Rohsnapshots.
  - Die Read-API ist nur für aktive Teilnehmende gemäß Teilnahme- und Zugangslogik zugänglich.
  - Die Antwort enthält Transparenz-Metadaten wie Datenstand und Hinweise auf den Annäherungscharakter.
- Abhängigkeiten: Ticket 6, Ticket 7.
- Nicht Teil dieses Tickets: Regionale Vergleichsansichten, Admin-Oberflächen, Live-Auswertungen auf Snapshot-Historien.

### Ticket 9: Tests und lokales Setup dokumentieren und absichern

- Titel: Tests und lokales Setup dokumentieren und absichern
- Typ: Qualität
- Priorität: P1
- Status: offen
- Ziel: Lokale Entwicklung und Qualitätsabsicherung für den Server reproduzierbar machen.
- Kurzbeschreibung: Für den MVP sollen lokales Docker-Setup, lokale MongoDB-Nutzung sowie automatisierte Tests so dokumentiert und abgesichert werden, dass Ingest, Persistenz, Aggregation und Read-API lokal nachvollziehbar geprüft werden können.
- Akzeptanzkriterien:
  - Das Docker-Setup ist lokal startbar.
  - MongoDB kann lokal für Entwicklung und Tests verwendet werden.
  - Integrationstests für Ingest- und Read-Pfad sind lokal ausführbar.
  - Die lokale Dokumentation beschreibt den minimalen Ablauf vom Start bis zum Testlauf.
- Abhängigkeiten: Ticket 1, Ticket 2, Ticket 4, Ticket 8.
- Nicht Teil dieses Tickets: Produktionsdeployment, Monitoring-Infrastruktur, Lasttests.

### Ticket 10: Stabilen MongoDB-Betrieb für Serverumgebung absichern

- Titel: Stabilen MongoDB-Betrieb für Serverumgebung absichern
- Typ: Architektur
- Priorität: P1
- Status: offen
- Ziel: Den produktionsnahen Betrieb der MongoDB für den Statistikserver robust und nachvollziehbar absichern.
- Kurzbeschreibung: Für Serverumgebungen außerhalb der lokalen Entwicklung sollen Persistenz, Authentifizierung, Backup- und Restore-Abläufe, Monitoring sowie das Verhalten bei Datenbankausfällen konzipiert und dokumentiert werden. Dieses Ticket ergänzt bewusst erst nach dem Basisgerüst die Anforderungen für einen stabilen Datenbankbetrieb.
- Akzeptanzkriterien:
  - Anforderungen an Persistenz und Datensicherung sind dokumentiert.
  - Ein Backup- und Restore-Ablauf für die MongoDB ist beschrieben.
  - Grundlegende Anforderungen an Authentifizierung, Secrets und Betriebsmonitoring sind festgehalten.
  - Das gewünschte Verhalten des Servers bei temporären MongoDB-Ausfällen ist geklärt.
- Abhängigkeiten: Ticket 1.
- Nicht Teil dieses Tickets: Fachliche Snapshot-Verarbeitung, Aggregationslogik, Read-API.

## Spätere Ausbaustufen

- Komplexere Snapshot-Auswahl bei mehreren Sendern desselben Stammes.
- Regionale Vergleiche für Bezirk und DV erst nach dem MVP.
- Statische Verbandszahlen als getrennte Referenzquelle ergänzen.
- Transparenz- und Admin-Werkzeuge für Einsicht, Fehleranalyse und Nachvollziehbarkeit ergänzen.
- Verfeinerte Regeln für Teilnahmehistorie, Widerrufe und Governance nach dem MVP ausbauen.

## Offene Punkte für später

- Die Auswahl des maßgeblichen Snapshots bei konkurrierenden Sendern desselben Stammes wird nach dem MVP geschärft.
- Regionale Vergleiche und statische Referenzdaten bleiben spätere Ausbaustufen.
- Ein ausgefeilter Vollständigkeitsvergleich konkurrierender Sender ist nicht Teil des MVP.
- Zu klären bleibt später, ob und wie historische Daten bei verschärften Datenschutzanforderungen nachträglich behandelt werden sollen.

## Empfohlene nächste Reihenfolge ab aktuellem Stand

1. Effektiven Stammestand je Stamm aus `raw_snapshots` in `effective_states` ableiten.
2. Teilnahme-, Widerrufs- und 14-Tage-Zugangslogik fachlich und technisch in den Serverfluss integrieren.
3. Wöchentliche Bundesaggregation auf Basis des materialisierten effektiven Stammestands einführen.
4. Read-API für materialisierte Bundesaggregate mit Transparenz-Metadaten bereitstellen.
5. Lokales Setup, Integrationstests und minimale Betriebsdokumentation absichern.
6. Stabilen MongoDB-Betrieb für Serverumgebungen absichern.

## Hinweis zur Nutzung in GitHub

Die Ticketabschnitte können in dieser Form direkt als Grundlage für einzelne GitHub Issues übernommen werden.
