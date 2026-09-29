import 'auth_profile.dart';

abstract class AuthProfileRepository {
  Future<AuthProfile?> loadCached();

  Future<void> save(AuthProfile profile);

  Future<void> clear();

  Future<DateTime?> loadLastSyncAt();

  Future<void> saveLastSyncAt(DateTime timestamp);
}
