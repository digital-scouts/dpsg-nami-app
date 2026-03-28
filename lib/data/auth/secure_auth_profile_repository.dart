import 'dart:convert';

import '../../domain/auth/auth_profile.dart';
import '../../domain/auth/auth_profile_repository.dart';
import '../../services/sensitive_storage_service.dart';

class SecureAuthProfileRepository implements AuthProfileRepository {
  SecureAuthProfileRepository({
    required SensitiveStorageService sensitiveStorageService,
  }) : _sensitiveStorageService = sensitiveStorageService;

  static const String _boxName = 'hitobito_profile_box';
  static const String _profileKey = 'auth_profile_v1';
  static const String _lastSyncAtKey = 'auth_profile_last_sync_at';

  final SensitiveStorageService _sensitiveStorageService;

  @override
  Future<void> clear() async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    await box.delete(_profileKey);
    await box.delete(_lastSyncAtKey);
  }

  @override
  Future<AuthProfile?> loadCached() async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    final raw = box.get(_profileKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return AuthProfile.fromJson(decoded);
  }

  @override
  Future<DateTime?> loadLastSyncAt() async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    final raw = box.get(_lastSyncAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  @override
  Future<void> save(AuthProfile profile) async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    await box.put(_profileKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<void> saveLastSyncAt(DateTime timestamp) async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    await box.put(_lastSyncAtKey, timestamp.toIso8601String());
  }
}
