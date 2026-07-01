import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/auth/auth_session.dart';
import '../../domain/auth/auth_session_repository.dart';

class SecureAuthSessionRepository implements AuthSessionRepository {
  static const String _storageKey = 'hitobito_auth_session_v1';

  final FlutterSecureStorage storage;

  SecureAuthSessionRepository({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<AuthSession?> load() async {
    final raw = await storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return AuthSession.fromJson(decoded);
  }

  @override
  Future<void> save(AuthSession session) async {
    await storage.write(key: _storageKey, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    await storage.delete(key: _storageKey);
  }
}
