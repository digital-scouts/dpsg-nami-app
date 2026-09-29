# Betrieb auf dem vServer

Der Statistikserver läuft auf demselben vServer wie der DPSG-News-Stack und ist unter `https://namiapp.scout-link.de` erreichbar. Er nutzt dessen Caddy für TLS und Reverse-Proxy, bringt aber eine eigene MongoDB mit und wird als eigenes Compose-Projekt `nami-statistics` betrieben.

| Datei | Zweck | Ziel auf dem Host |
| --- | --- | --- |
| `docker-compose.server.yml` | Statistikserver und MongoDB | `/opt/nami-statistics/` |
| `server.env.example` | Vorlage für Secrets und Laufzeitkonfiguration | `/opt/nami-statistics/.env` |
| `namiapp.caddy` | Caddy-Site für `namiapp.scout-link.de` | `/opt/caddy-sites/` |
| `backup.sh` | Tägliches MongoDB-Backup | `/opt/nami-statistics/` |

Compose-Datei, Backup-Skript und Caddy-Site kopiert der Workflow `.github/workflows/server-deploy.yml` bei jedem Deploy. Nur die `.env` wird einmalig von Hand angelegt.

## Voraussetzungen

- Der News-Stack läuft unter `/opt/dpsg-news` mit dem Compose-Projekt `dpsg-news`. Docker, `ufw` (22/80/443) und der `deploy`-User sind vorhanden.
- Das Caddyfile im Repo `DPSG-News-APP` enthält am Ende `import /etc/caddy/sites/*.caddy`. Die News-Compose mountet `/opt/caddy-sites:/etc/caddy/sites:ro` in den Caddy-Container. Der News-Deploy überschreibt das Caddyfile bei jedem Lauf, deshalb gehört diese Änderung ins News-Repo und nicht direkt auf den Server.
- Der A-Record `namiapp.scout-link.de` zeigt auf den vServer.
- Im GitHub-Repo `digital-scouts/dpsg-nami-app` gibt es das Environment `statistics-server` mit den Secrets `DOCKERHUB_TOKEN`, `SSH_USER` und `SSH_PRIVATE_KEY` sowie den Variablen `SSH_HOST` und `SSH_PORT`.

## Ersteinrichtung

Als `deploy`-User auf dem vServer:

```bash
sudo mkdir -p /opt/nami-statistics /opt/caddy-sites
sudo chown deploy:deploy /opt/nami-statistics /opt/caddy-sites

# Name des Caddy-Netzes und des Containers prüfen (Default: dpsg-news_default)
docker network ls | grep dpsg-news
docker ps --filter label=com.docker.compose.service=caddy
```

Danach `server.env.example` als `/opt/nami-statistics/.env` anlegen und ausfüllen:

```bash
chmod 600 /opt/nami-statistics/.env
openssl rand -hex 32   # je einmal für MONGO_ROOT_PASSWORD, PSEUDONYMIZATION_SECRET, SENDER_SECRET_PEPPER
```

`MONGO_ROOT_PASSWORD` muss auch in `MONGODB_URI` stehen. Ein Passwort aus `openssl rand -hex` enthält keine Zeichen, die in der URI maskiert werden müssen.

Anschließend den ersten Deploy manuell über **Actions → Deploy Statistics Server → Run workflow** starten und den Backup-Cron einrichten:

```bash
crontab -e
# 15 3 * * * /opt/nami-statistics/backup.sh >> /opt/nami-statistics/backups/backup.log 2>&1
```

## Deploy und Updates

- Ein Push auf `develop` oder `master` mit Änderungen unter `server/` löst den Deploy aus: Validierung, Image `sapza/nami-statistics:<git-sha>`, Kopieren der Dateien, `docker compose up --wait`, Caddy-Reload und Prüfung von `/health/ready` auf den neuen SHA.
- Ohne Push lässt sich der Deploy per `workflow_dispatch` auslösen.
- MongoDB hat bewusst kein Watchtower-Label. Ein Update der Datenbank erfolgt nur geplant: Backup ziehen, Image-Tag in `docker-compose.server.yml` anpassen, deployen.

Manuell auf dem Host:

```bash
cd /opt/nami-statistics
docker compose -p nami-statistics --env-file .env -f docker-compose.server.yml ps
docker compose -p nami-statistics --env-file .env -f docker-compose.server.yml logs --tail 100 nami-statistics
```

Immer mit `-p nami-statistics` arbeiten. Ohne festen Projektnamen könnte `--remove-orphans` Container des News-Stacks erfassen.

## Backup und Restore

`backup.sh` schreibt täglich `backups/nami_statistics_<zeit>.archive.gz`, behält 14 Tage und setzt danach in `ops_status` den Marker `last_success_at`. Den Marker liest `/health/ready`, und der tägliche Status-Check schlägt fehl, wenn das letzte Backup älter als 36 Stunden ist.

Restore, z. B. zur Probe in eine separate Datenbank:

```bash
cd /opt/nami-statistics
docker compose -p nami-statistics --env-file .env -f docker-compose.server.yml exec -T mongodb sh -c \
  'mongorestore --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --archive --gzip --nsFrom "nami_statistics.*" --nsTo "restore_check.*"' \
  < backups/nami_statistics_<zeit>.archive.gz
```

Für einen echten Restore `--drop` ergänzen und `--nsFrom`/`--nsTo` weglassen. Danach den Server neu starten, damit er `effective_states` und das Aggregat neu aufbaut.

Die Backups liegen auf demselben vServer. Gegen einen Totalausfall des Servers hilft nur eine zusätzliche Kopie an einem anderen Ort (z. B. per `rsync` auf einen Rechner außerhalb).

## Monitoring

Der Workflow `.github/workflows/server-status.yml` läuft täglich um 06:00 UTC und prüft:

- `/health/ready`: Server und MongoDB
- das Alter des letzten Backups
- die Gültigkeit des TLS-Zertifikats und die Weiterleitung von HTTP auf HTTPS
- ob die laufende Version dem letzten Deploy entspricht
- dass Port 27017 von außen nicht erreichbar ist

Bei einem Fehler legt er ein Issue mit dem Label `server-status` an oder kommentiert ein offenes. Weil Caddy zum News-Stack gehört, zeigt der Check auch dessen Ausfall an.

Verhalten bei einem MongoDB-Ausfall:

- Der Server startet nur mit erreichbarer Datenbank.
- Fällt MongoDB im laufenden Betrieb aus, antworten Ingest und Read-API mit `500 internal_error` und `/health/ready` mit `503`.
- Der Liveness-Check `/health` bleibt grün, damit Docker den Server nicht unnötig neu startet. Der MongoDB-Treiber verbindet sich selbstständig neu.
- Die App verwirft fehlgeschlagene Sendungen nicht dauerhaft, sondern versucht es beim nächsten Synchronisieren erneut.

## Secrets

- `PSEUDONYMIZATION_SECRET` bestimmt alle Stamm- und Sender-Pseudonyme. Ein Wechsel trennt neue Snapshots von den bisherigen Daten und macht alle Installationen unbekannt.
- `SENDER_SECRET_PEPPER` bestimmt die Hashes der Installations-Secrets. Ein Wechsel macht alle registrierten Installationen ungültig. Die App erzeugt bei `invalid_sender_credentials` automatisch neue Credentials und gilt bis zum nächsten erfolgreichen Senden als nicht teilnehmend.
- Beide Werte deshalb nicht routinemäßig rotieren, sondern nur bei Verdacht auf Kompromittierung, und dann bewusst mit einem Neustart der Statistik (Datenbank leeren).
- `MONGO_ROOT_PASSWORD` lässt sich rotieren: in MongoDB per `db.changeUserPassword` ändern, danach `.env` anpassen und neu deployen.
