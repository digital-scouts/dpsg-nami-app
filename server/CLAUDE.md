# Statistikserver (server/)

Gilt zusaetzlich zu den Root-Regeln in [../CLAUDE.md](../CLAUDE.md).

## Isolation

- Implementierung, Skripte, Konfiguration und Tests bleiben in server/, sofern nicht bewusst eine Root-Workflow- oder geteilte Dokumentationsdatei aktualisiert werden muss.
- Keine Importe, Ausfuehrung oder Abhaengigkeit von Flutter-Quellen oder Dateien unter lib/, test/, tool/, android/ oder ios/.
- Server-CI laeuft mit working-directory: server und nutzt ausschliesslich Node.js- sowie server-lokale Befehle.
- Bevorzuge docker-compose und MongoDB gegenueber host-installierten Datenbank-Tools.

## Befehle (auszufuehren in server/)

- Dependencies installieren: `npm install`
- Lokale Datenbank starten: `npm run dev:db`
- Typecheck: `npm run typecheck`
- Tests ausfuehren: `npm test`
- Build: `npm run build`
