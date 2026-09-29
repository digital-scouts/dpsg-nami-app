import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/bundesstatistik/installation_credentials.dart';

/// Speichert die Installations-Credentials im sicheren Speicher des Geraets.
///
/// Sie ueberstehen bewusst Logout und Nutzerwechsel (sie gehoeren zur
/// Installation, nicht zur Person) und werden nur beim App-Reset geloescht.
class SecureInstallationCredentialsRepository
    implements InstallationCredentialsRepository {
  SecureInstallationCredentialsRepository({
    FlutterSecureStorage? secureStorage,
    Random? random,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _random = random ?? Random.secure();

  static const String _idKey = 'bundesstatistik_installation_id';
  static const String _secretKey = 'bundesstatistik_installation_secret';

  final FlutterSecureStorage _secureStorage;
  final Random _random;

  @override
  Future<InstallationCredentials> loadOrCreate() async {
    final id = await _secureStorage.read(key: _idKey);
    final secret = await _secureStorage.read(key: _secretKey);
    if (id != null && id.isNotEmpty && secret != null && secret.isNotEmpty) {
      return InstallationCredentials(id: id, secret: secret);
    }
    return regenerate();
  }

  @override
  Future<InstallationCredentials> regenerate() async {
    final credentials = InstallationCredentials(
      id: _randomToken(16),
      secret: _randomToken(32),
    );
    await _secureStorage.write(key: _idKey, value: credentials.id);
    await _secureStorage.write(key: _secretKey, value: credentials.secret);
    return credentials;
  }

  @override
  Future<void> clear() async {
    await _secureStorage.delete(key: _idKey);
    await _secureStorage.delete(key: _secretKey);
  }

  String _randomToken(int byteCount) {
    final bytes = List<int>.generate(byteCount, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
