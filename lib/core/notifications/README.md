# Pull Notifications Modul

Dieses Modul implementiert die Kernlogik für Pull Notifications gemäß der Spezifikation in `specs/pull-notifications.md`.

## Struktur

- `pull_notification.dart`: Model & JSON-Parser
- `pull_notifications_repository.dart`: Repository-Interface
- `remote_notifications_data_source.dart`: HTTP-Loader
- `local_notifications_data_source.dart`: Hive-Cache & Ack-Logik
- `asset_notifications_data_source.dart`: Asset-Quelle für die Entwicklung
- `pull_notifications_filter.dart`: Plattform- und Zeitfenster-Filter
- `notifications_parser_test.dart`: Unit-Tests für Model/Parser

## Hinweise

- Die URL zur JSON-Quelle wird aus der `.env` geladen.
- Remote-Checks werden ueber ein Mindestintervall aus der `.env` gedrosselt.
- Das Feld `platform` ist optional, Default ist `all`.
- `created_at` und `updated_at` sind optional.
- Mehrsprachigkeit: `title` und `body` als Map (`de`, `en`).
- ACK-Status wird lokal in Hive gespeichert (`notifications_ack_box`).

## Filter, Links und Entwicklung

- `pull_notifications_filter.dart` filtert nach `platform` und `starts_at`/`ends_at`; das Repository wendet es auf jede Ausgabe an.
- Links öffnet `lib/presentation/notifications/notification_links.dart`.
- `asset_notifications_data_source.dart` liest den Feed aus dem Asset in `PULL_NOTIFICATIONS_ASSET` (nur außerhalb von Release-Builds).
