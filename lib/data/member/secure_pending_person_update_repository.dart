import 'dart:convert';

import '../../domain/member/pending_person_update.dart';
import '../../domain/member/pending_person_update_repository.dart';
import '../../services/sensitive_storage_service.dart';

class SecurePendingPersonUpdateRepository
    implements PendingPersonUpdateRepository {
  SecurePendingPersonUpdateRepository({
    required SensitiveStorageService sensitiveStorageService,
  }) : _sensitiveStorageService = sensitiveStorageService;

  static const String boxName = 'hitobito_pending_person_updates_box';
  static const String _cacheKey = 'pending_person_updates_v1';

  final SensitiveStorageService _sensitiveStorageService;

  @override
  Future<void> clear() async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(boxName);
    await box.delete(_cacheKey);
  }

  @override
  Future<List<PendingPersonUpdate>> loadAll() async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(boxName);
    final raw = box.get(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return const <PendingPersonUpdate>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <PendingPersonUpdate>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((json) {
          try {
            return PendingPersonUpdate.fromJson(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<PendingPersonUpdate>()
        .where((entry) => entry.entryId.isNotEmpty && entry.personId > 0)
        .toList(growable: false);
  }

  @override
  Future<void> remove(String entryId) async {
    final current = await loadAll();
    final filtered = current
        .where((entry) => entry.entryId != entryId)
        .toList();
    await _saveAll(filtered);
  }

  @override
  Future<void> save(PendingPersonUpdate entry) async {
    final current = await loadAll();
    final next = <PendingPersonUpdate>[];
    var replaced = false;
    for (final existing in current) {
      if (existing.entryId == entry.entryId) {
        next.add(entry);
        replaced = true;
        continue;
      }
      next.add(existing);
    }
    if (!replaced) {
      next.add(entry);
    }
    await _saveAll(next);
  }

  Future<void> _saveAll(List<PendingPersonUpdate> entries) async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(boxName);
    await box.put(
      _cacheKey,
      jsonEncode(
        entries.map((entry) => entry.toJson()).toList(growable: false),
      ),
    );
  }
}
