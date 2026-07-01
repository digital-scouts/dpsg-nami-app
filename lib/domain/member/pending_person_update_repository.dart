import 'pending_person_update.dart';

abstract class PendingPersonUpdateRepository {
  Future<List<PendingPersonUpdate>> loadAll();

  Future<void> save(PendingPersonUpdate entry);

  Future<void> remove(String entryId);

  Future<void> clear();
}
