import 'package:nami/domain/stufe/altersgrenzen.dart';

abstract class StufenSettingsRepository {
  Future<Altersgrenzen> load();
  Future<void> save(Altersgrenzen grenzen);
  Stream<Altersgrenzen> watch();
}
