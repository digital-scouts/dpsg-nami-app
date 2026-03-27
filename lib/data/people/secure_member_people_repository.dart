import 'dart:convert';

import '../../domain/member/member_people_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../services/hitobito_people_service.dart';
import '../../services/sensitive_storage_service.dart';

class SecureMemberPeopleRepository implements MemberPeopleRepository {
  SecureMemberPeopleRepository({
    required HitobitoPeopleService remoteService,
    required SensitiveStorageService sensitiveStorageService,
  }) : _remoteService = remoteService,
       _sensitiveStorageService = sensitiveStorageService;

  static const String _boxName = 'hitobito_people_box';
  static const String _cacheKey = 'people_list_v1';

  final HitobitoPeopleService _remoteService;
  final SensitiveStorageService _sensitiveStorageService;

  @override
  Future<List<Mitglied>> loadCached() async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    final raw = box.get(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return const <Mitglied>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <Mitglied>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Mitglied.fromPeopleListJson)
        .toList();
  }

  @override
  Future<List<Mitglied>> refresh(String accessToken) async {
    final people = await _remoteService.fetchPeople(accessToken);
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    await box.put(
      _cacheKey,
      jsonEncode(
        people.map((mitglied) => mitglied.toPeopleListJson()).toList(),
      ),
    );
    return people;
  }
}
