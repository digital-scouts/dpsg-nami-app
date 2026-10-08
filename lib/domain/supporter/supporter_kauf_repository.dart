import 'supporter_produkt.dart';

/// Merkt sich den zuletzt vom Store bestaetigten Kaufstand, damit
/// Freischaltungen offline erhalten bleiben.
abstract class SupporterKaufRepository {
  Future<GekaufterSupportAccess> load();

  Future<void> save(GekaufterSupportAccess access);
}

class InMemorySupporterKaufRepository implements SupporterKaufRepository {
  InMemorySupporterKaufRepository([
    this._access = const GekaufterSupportAccess(),
  ]);

  GekaufterSupportAccess _access;

  @override
  Future<GekaufterSupportAccess> load() async => _access;

  @override
  Future<void> save(GekaufterSupportAccess access) async => _access = access;
}
