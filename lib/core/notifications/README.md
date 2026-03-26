# Pull Notifications Modul

Dieses Modul implementiert die Kernlogik für Pull Notifications gemäß der Spezifikation in `specs/pull-notifications.md`.

## Struktur

- `pull_notification.dart`: Model & JSON-Parser
- `pull_notifications_repository.dart`: Repository-Interface
- `remote_notifications_data_source.dart`: HTTP-Loader
- `local_notifications_data_source.dart`: Hive-Cache & Ack-Logik
- `notifications_parser_test.dart`: Unit-Tests für Model/Parser

## Hinweise

- Die URL zur JSON-Quelle wird aus der `.env` geladen.
- Remote-Checks werden ueber ein Mindestintervall aus der `.env` gedrosselt.
- Das Feld `platform` ist optional, Default ist `all`.
- `created_at` und `updated_at` sind optional.
- Mehrsprachigkeit: `title` und `body` als Map (`de`, `en`).
- ACK-Status wird lokal in Hive gespeichert (`notifications_ack_box`).

## Nächste Schritte

- Plattform-Filterung ueber `platform` zentral anwenden.
- Aktivitaetsfenster ueber `starts_at` und `ends_at` auswerten.
- Detailansicht bzw. `deep_link`/`external_link` umsetzen.
- Optionalen Asset-Fallback fuer Entwicklungszwecke ergaenzen.
