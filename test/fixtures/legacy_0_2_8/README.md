# Fixture: lokale Daten der App-Version 0.2.8

Diese Dateien wurden mit dem echten Hive-Code der App-Version 0.2.8 (Tag `v0.2.8`) erzeugt. Sie bilden den Datenstand ab, den ein Gerät beim Update auf 1.0.0 mitbringt. Alle Inhalte sind Fake-Daten.

- `*.hive`: verschlüsselte Hive-Boxen (Hive speichert Boxnamen kleingeschrieben, z. B. `settingsBox` als `settingsbox.hive`)
- `secure_storage.json`: Secure-Storage-Einträge `key` (Hive-AES-Schlüssel) und `salt`
- `prod.log`: Logdatei der alten Version

Neu erzeugen:

```sh
tool/legacy_fixture/generate_0_2_8_fixture.sh
```

Verwendet in `test/legacy_app_data_cleanup_service_test.dart` und `test/upgrade_from_0_2_8_startup_test.dart`.
