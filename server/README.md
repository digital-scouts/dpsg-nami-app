# Statistikserver

Dieses Verzeichnis enthält das eigenständige Grundgerüst für den Statistikserver. Der Server bleibt technisch unter `server/` isoliert und greift nicht auf Flutter-Code oder Buildlogik außerhalb dieses Verzeichnisses zu.

## Basis

- Laufzeit: Node.js LTS
- Sprache: TypeScript
- HTTP-Framework: Fastify
- Lokale Infrastruktur: MongoDB über Docker Compose, Server direkt auf dem Host
- Produktivpfad: Server und MongoDB über Docker Compose

## Lokale Entwicklung

Primärer lokaler Entwicklungsweg:

```bash
cd server
npm install
npm run dev:db
npm run dev
```

Danach ist der Health-Endpunkt unter `http://localhost:3000/health` erreichbar.

MongoDB läuft lokal dabei in Docker unter `mongodb://localhost:27017`.

Für den Start muss zusätzlich `PSEUDONYMIZATION_SECRET` gesetzt sein. Der Wert muss stabil bleiben, damit Stamm- und Sender-Pseudonyme für identische Eingaben reproduzierbar bleiben.

Der Server startet nur erfolgreich, wenn beim Boot eine MongoDB-Verbindung aufgebaut werden kann. Für die lokale Entwicklung läuft der Server direkt auf dem Host, damit Watch-Modus, Breakpoints und sonstige Dev-Tools einfacher nutzbar bleiben.

Zum Stoppen und Bereinigen:

```bash
cd server
npm run dev:db:down
```

## Produktivstart mit Docker

Für den containerisierten Produktivpfad werden Server und MongoDB gemeinsam über eine eigene Compose-Datei gestartet:

```bash
cd server
npm run docker:prod:up
```

Zum Stoppen:

```bash
cd server
npm run docker:prod:down
```

## Direkter Node-Start

Falls der Dienst ohne Compose gestartet werden soll:

```bash
cd server
npm install
npm run dev
```

Für diesen Pfad muss eine erreichbare MongoDB per `MONGODB_URI` konfiguriert sein.
Zusätzlich muss `PSEUDONYMIZATION_SECRET` gesetzt sein.

## Aktueller API-Stand

- `GET /health`: einfacher Health-Check mit Statusantwort
- `POST /snapshots/stamm`: validiert Stammes-Snapshots gegen die aktuell unterstützte Schema-Version `2026-04-01`

Der Snapshot-Ingest persistiert im aktuellen Stand gültige, pseudonymisierte Rohsnapshots in MongoDB. `effective_states` und `weekly_aggregates` werden dabei bereits strukturell vorbereitet, aber noch nicht fachlich befüllt. Bei erfolgreicher Verarbeitung liefert der Endpunkt `204 No Content`.

Ungültige Anfragen liefern `400` mit einer strukturierten Fehlerantwort in der Form:

```json
{
  "error": {
    "code": "missing_required_field",
    "message": "Snapshot payload is invalid",
    "fields": ["dv_id"]
  }
}
```

Die fachlichen Details des Snapshot-Vertrags liegen unter `server/spec/stammes_snapshot.md`.

## Skripte

- `npm run dev`: Entwicklungsserver mit Watch-Modus
- `npm run typecheck`: TypeScript-Prüfung ohne Build
- `npm run test`: Testlauf
- `npm run build`: Produktionsbuild nach `dist/`

## Trennung zum Flutter-Projekt

- Server-spezifische CI läuft getrennt von den Flutter-Workflows.
- Server-Befehle werden mit `working-directory: server` ausgeführt.
- Flutter-Code und Server-Code dürfen nur über explizite API-Verträge gekoppelt werden, nicht über direkte Datei- oder Build-Abhängigkeiten.
