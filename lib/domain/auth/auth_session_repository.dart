import 'auth_session.dart';

abstract class AuthSessionRepository {
  Future<AuthSession?> load();

  Future<void> save(AuthSession session);

  Future<void> clear();
}
