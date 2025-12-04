import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufe/stufen_settings_repository.dart';

class GetAltersgrenzenUseCase {
  final StufenSettingsRepository repo;
  GetAltersgrenzenUseCase(this.repo);

  Future<Altersgrenzen> call() => repo.load();
  Stream<Altersgrenzen> watch() => repo.watch();
}
