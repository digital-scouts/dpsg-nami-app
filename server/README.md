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

Für den Start müssen zusätzlich `PSEUDONYMIZATION_SECRET` und `SENDER_SECRET_PEPPER` gesetzt sein, z. B. über `server/.env` nach dem Vorbild von `server/.env.example`. Beide Werte müssen stabil bleiben: Das Secret hält Stamm- und Sender-Pseudonyme reproduzierbar, der Pepper die gespeicherten Hashes der Installations-Secrets.

Beim Start baut der Server `effective_states` und das aktuelle Wochenaggregat aus `raw_snapshots` neu auf.

Datenbestände aus der Zeit vor der Umstellung auf UTC-Datumsfelder (Zeitstempel als Strings) werden nicht migriert. Lokale Entwicklungsdatenbanken dafür mit `npm run dev:db:down` und `docker volume rm server_mongodb_data` verwerfen.

Mit `STORAGE_BACKEND=mongodb` (Default) startet der Server nur erfolgreich, wenn beim Boot eine MongoDB-Verbindung aufgebaut werden kann. Für die lokale Entwicklung läuft der Server direkt auf dem Host, damit Watch-Modus, Breakpoints und sonstige Dev-Tools einfacher nutzbar bleiben.

Ohne MongoDB lässt sich der Server im Speichermodus mit synthetischen Stämmen starten, so wie die Mock-Instanz unter `mock-namiapp.scout-link.de`:

```bash
cd server
STORAGE_BACKEND=memory MOCK_SEED_STAMM_COUNT=30 npm run dev
```

Die Daten gehen beim Neustart verloren. `MOCK_SEED_STAMM_COUNT` ist nur mit `STORAGE_BACKEND=memory` erlaubt. Details zur Mock-Instanz stehen in `server/deploy/README.md`.

Zum Stoppen und Bereinigen:

```bash
cd server
npm run dev:db:down
```

## Produktivstart mit Docker

Für einen vollständig containerisierten Test werden Server und MongoDB gemeinsam über `docker-compose.prod.yml` gestartet. Die Secrets kommen aus `server/.env.production` (nicht committet) mit `PSEUDONYMIZATION_SECRET`, `SENDER_SECRET_PEPPER`, `MONGO_ROOT_USERNAME` und `MONGO_ROOT_PASSWORD`. MongoDB ist dabei nur im Compose-Netz erreichbar, der Server nur unter `127.0.0.1:3000`.

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
Zusätzlich müssen `PSEUDONYMIZATION_SECRET` und `SENDER_SECRET_PEPPER` gesetzt sein.

Der Betrieb auf dem vServer mit Caddy, Deploy-Workflow, Backups und Monitoring ist in `server/deploy/README.md` beschrieben.

## Aktueller API-Stand

- `GET /health`: Liveness-Check für den Docker-Healthcheck
- `GET /health/ready`: Readiness-Check mit MongoDB-Ping, laufender Version (`GIT_SHA`), letztem Backup und Zeitpunkt des letzten Aggregats; `503`, wenn MongoDB nicht erreichbar ist
- `POST /snapshots/stamm`: nimmt Stammes-Snapshots im Schema `2026-04-01` mit Installations-Credentials an, pseudonymisiert und speichert sie, aktualisiert den effektiven Stand des Stammes und das Wochenaggregat; Erfolg ist `204 No Content`
- `GET /aggregates/bund/latest`: liefert das materialisierte Bundesaggregat an Installationen, die in den letzten 14 Tagen erfolgreich gesendet haben

Fehler liefern eine strukturierte Antwort in der Form:

```json
{
  "error": {
    "code": "missing_required_field",
    "message": "Snapshot payload is invalid",
    "fields": ["stamm_id"]
  }
}
```

Interne Fehler werden ohne Details als `internal_error` ausgeliefert. Ingest und Read-API sind pro Client-IP begrenzt (`RATE_LIMIT_*`), Anfragen sind auf `BODY_LIMIT_BYTES` begrenzt. CORS ist bewusst nicht aktiviert, weil nur die native App zugreift.

Die Verträge liegen unter `server/spec/stammes_snapshot.md` und `server/spec/bundesaggregat.md`.

## Skripte

- `npm run dev`: Entwicklungsserver mit Watch-Modus
- `npm run typecheck`: TypeScript-Prüfung von Quellcode und Tests ohne Build
- `npm run test`: Unit- und Integrationstests; die Integrationstests starten per `mongodb-memory-server` eine echte MongoDB 7.0 (beim ersten Lauf wird das Binary heruntergeladen), Docker ist dafür nicht nötig
- `npm run build`: Produktionsbuild nach `dist/`

## Trennung zum Flutter-Projekt

- Server-spezifische CI läuft getrennt von den Flutter-Workflows.
- Server-Befehle werden mit `working-directory: server` ausgeführt.
- Flutter-Code und Server-Code dürfen nur über explizite API-Verträge gekoppelt werden, nicht über direkte Datei- oder Build-Abhängigkeiten.
