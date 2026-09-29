/// Zufaellige Kennung dieser App-Installation fuer den Statistikserver.
///
/// Die ID ist keine Personen- oder Geraetekennung. Das Secret belegt nur, dass
/// Anfragen von derselben Installation stammen (Trust on First Use).
class InstallationCredentials {
  const InstallationCredentials({required this.id, required this.secret});

  final String id;
  final String secret;
}

abstract class InstallationCredentialsRepository {
  /// Liefert die gespeicherten Credentials oder legt neue an.
  Future<InstallationCredentials> loadOrCreate();

  /// Verwirft die bisherigen Credentials und legt neue an.
  Future<InstallationCredentials> regenerate();

  Future<void> clear();
}
