import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/domain/member/pending_person_update_repository.dart';

/// Pending-Speicher im Arbeitsspeicher mit derselben Ersetzungsregel wie
/// `SecurePendingPersonUpdateRepository`: Ein Eintrag mit gleicher `entryId`
/// oder gleicher `personId` wird ersetzt.
class InMemoryPendingPersonUpdateRepository
    implements PendingPersonUpdateRepository {
  InMemoryPendingPersonUpdateRepository({
    List<PendingPersonUpdate> entries = const <PendingPersonUpdate>[],
  }) : _entries = List<PendingPersonUpdate>.from(entries);

  final List<PendingPersonUpdate> _entries;

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  @override
  Future<List<PendingPersonUpdate>> loadAll() async {
    return List<PendingPersonUpdate>.unmodifiable(_entries);
  }

  @override
  Future<void> remove(String entryId) async {
    _entries.removeWhere((entry) => entry.entryId == entryId);
  }

  @override
  Future<void> save(PendingPersonUpdate entry) async {
    final index = _entries.indexWhere(
      (existing) =>
          existing.entryId == entry.entryId ||
          existing.personId == entry.personId,
    );
    if (index >= 0) {
      _entries[index] = entry;
      return;
    }
    _entries.add(entry);
  }
}
