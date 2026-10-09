# Mitgliederdaten in der Entwicklung

Stand: 2026-10-09. Gilt für alle, die an der App oder am Statistikserver arbeiten. Mitgliederdaten gehören der DPSG und sind überwiegend Daten von Kindern und Jugendlichen. In der Entwicklung brauchen wir sie fast nie.

## Grundsatz

Entwickelt und getestet wird mit synthetischen Daten. Echte Mitgliederdaten verlassen das Gerät der angemeldeten Leitung nur in den Fällen unten und nie in Repo, Issues, PRs, Chats oder Screenshots.

## Synthetische Daten

- Tests, Storybook und Store-Bilder nutzen Faker- und Demo-Daten (`lib/stories`, `test/support`).
- Contract-Tests laufen gegen die Demo-Instanz (`demo.hitobito.com`) oder einen lokalen Stack mit Testdaten.
- Der Pre-Commit-Hook (`tool/validate_tracked_files.dart`) sperrt API-Mitschnitte (`.har`, Postman, `.xcappdata`, `specs/demoResponse/`). Ihn nicht umgehen.

## Wenn es doch echte Daten braucht

- **Testgerät mit echtem Zugang:** nur das eigene Konto, App-Sperre an, nach dem Test abmelden (löscht die lokalen Daten). Kein Backup des App-Containers ziehen.
- **Zugesandte Logs (Problem melden, V7):** nur für die Analyse öffnen, nicht weiterleiten oder einchecken, danach löschen. Auszüge für Issues vorher von Namen, Adressen und Kontaktdaten befreien.
- **Wiredash-Feedback mit Screenshot (V2):** Screenshots mit Mitgliederdaten nach der Bearbeitung in der Wiredash-Konsole löschen.
- **Fehler nachstellen:** die Daten im lokalen Stack nachbauen, nicht kopieren.

## Was nie passiert

- Exporte, Datenbank- oder Hive-Kopien echter Mitglieder auf Entwicklungsrechnern aufbewahren.
- Echte Daten an KI-Dienste oder andere Dritte geben.
- Echte Daten in Testfixtures, Snapshots oder Golden-Bildern.
