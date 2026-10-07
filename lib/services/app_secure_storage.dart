import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage der App. Unter iOS bleiben die Eintraege an dieses Geraet
/// gebunden und wandern nicht ueber Backups oder Geraeteumzug mit.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
);

extension AppSecureStorageWrite on FlutterSecureStorage {
  /// Schreibt [value] und ersetzt dabei auch einen Eintrag mit anderer
  /// Zugriffsklasse. Unter iOS findet ein normales write solche Eintraege
  /// nicht und scheitert dann am doppelten Schluessel; delete wirkt ohne
  /// Zugriffsklasse.
  Future<void> writeReplacing({
    required String key,
    required String value,
  }) async {
    await delete(key: key);
    await write(key: key, value: value);
  }
}
